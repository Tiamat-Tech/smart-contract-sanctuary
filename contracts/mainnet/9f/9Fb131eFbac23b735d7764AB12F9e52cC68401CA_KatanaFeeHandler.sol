pragma solidity 0.6.6;

import "../utils/Utils5.sol";
import "../utils/zeppelin/ReentrancyGuard.sol";
import "../utils/zeppelin/SafeMath.sol";
import "../IKyberFeeHandler.sol";
import "../IKyberNetworkProxy.sol";
import "../ISimpleKyberProxy.sol";

import "../mock/reserves/ISanityRate.sol";
import "../mock/dao/IBurnableToken.sol";
import "../mock/dao/DaoOperator.sol";

/**
 * @title IKyberProxy
 *  This interface combines two interfaces.
 *  It is needed since we use one function from each of the interfaces.
 *
 */
interface IKyberProxy is IKyberNetworkProxy, ISimpleKyberProxy {
    // empty block
}

/**
 * @title kyberFeeHandler
 *
 * @dev kyberFeeHandler works tightly with contracts kyberNetwork and kyberDao.
 *   Some events are moved to interface, for easier usage
 * @dev Terminology:
 *   Epoch - Voting campaign time frame in kyberDao.
 *     kyberDao voting campaigns are in the scope of epochs.
 *   BRR - Burn / Reward / Rebate. kyberNetwork fee is used for 3 purposes:
 *     Burning KNC
 *     Reward an address that staked knc in kyberStaking contract. AKA - stakers
 *     Rebate reserves for supporting trades.
 * @dev Code flow:
 *    Per trade on kyberNetwork, it calls handleFees() function which
 *    internally accounts for network & platform fees from the trade. 
 *    Fee distribution:
 *      rewards: send to fee pool
 *      rebates: accumulated per rebate wallet, can be claimed any time.
 *      burn: accumulated in the contract. Burned value and interval limited with safe check using
 *        sanity rate.
 *      Platfrom fee: accumulated per platform wallet, can be claimed any time.
 */
contract KatanaFeeHandler is Utils5, DaoOperator, ReentrancyGuard, IKyberFeeHandler {
    using SafeMath for uint256;

    uint256 internal constant SANITY_RATE_DIFF_BPS = 1000; // 10%

    struct BRRData {
        uint16 rewardBps;
        uint16 rebateBps;
    }

    struct BRRWei {
        uint256 rewardWei;
        uint256 fullRebateWei;
        uint256 paidRebateWei;
        uint256 burnWei;
    }

    IKyberProxy public kyberProxy;
    address public feePool;
    IERC20 public immutable knc;

    uint256 public immutable burnBlockInterval;
    uint256 public lastBurnBlock;

    BRRData public brrData;

    /// @dev amount of eth to burn for each burn knc call
    uint256 public weiToBurn = 2 ether;

    mapping(address => uint256) public feePerPlatformWallet;
    mapping(address => uint256) public rebatePerWallet;
    // total balance in the contract that is for rebate, reward, platform fee
    uint256 public totalPayoutBalance;
    /// @dev use to get rate of KNC/ETH to check if rate to burn knc is normal
    /// @dev index 0 is currently used contract address, indexes > 0 are older versions
    ISanityRate[] internal sanityRateContract;

    event FeeDistributed(
        IERC20 indexed token,
        address indexed sender,
        address indexed platformWallet,
        uint256 platformFeeWei,
        uint256 rewardWei,
        uint256 rebateWei,
        address[] rebateWallets,
        uint256[] rebatePercentBpsPerWallet,
        uint256 burnAmtWei
    );

    event BRRUpdated(uint256 rewardBps, uint256 rebateBps, uint256 burnBps);

    event FeePoolUpdated(address feePool);

    event RebatePaid(address indexed rebateWallet, IERC20 indexed token, uint256 amount);

    event PlatformFeePaid(address indexed platformWallet, IERC20 indexed token, uint256 amount);

    event KncBurned(uint256 kncTWei, IERC20 indexed token, uint256 amount);

    event EthReceived(uint256 amount);

    event BurnConfigSet(ISanityRate sanityRate, uint256 weiToBurn);

    event DaoOperatorUpdated(address daoOperator);

    event KyberProxyUpdated(IKyberProxy kyberProxy);

    constructor(
        IKyberProxy _kyberProxy,
        IERC20 _knc,
        uint256 _burnBlockInterval,
        address _daoOperator,
        address _feePool,
        uint256 _rewardBps,
        uint256 _rebateBps
    ) public DaoOperator(_daoOperator) {
        require(_kyberProxy != IKyberProxy(0), "kyberNetworkProxy 0");
        require(_knc != IERC20(0), "knc 0");
        require(_burnBlockInterval != 0, "_burnBlockInterval 0");
        require(_feePool != address(0), "feePool 0");

        kyberProxy = _kyberProxy;
        knc = _knc;
        burnBlockInterval = _burnBlockInterval;
        feePool = _feePool;

        // set default brrData
        require(_rewardBps.add(_rebateBps) <= BPS, "Bad BRR values");
        brrData.rewardBps = uint16(_rewardBps);
        brrData.rebateBps = uint16(_rebateBps);
    }

    modifier onlyNonContract {
        require(tx.origin == msg.sender, "only non-contract");
        _;
    }

    receive() external payable {
        emit EthReceived(msg.value);
    }

    function setDaoOperator(address _daoOperator) external onlyDaoOperator {
        require(_daoOperator != address(0), "daoOperator 0");
        daoOperator = _daoOperator;

        emit DaoOperatorUpdated(_daoOperator);
    }

    /// @dev only call by daoOperator
    function setBRRData(
        uint256 _burnBps,
        uint256 _rewardBps,
        uint256 _rebateBps
    ) external onlyDaoOperator {
        require(_burnBps.add(_rewardBps).add(_rebateBps) == BPS, "Bad BRR values");
        brrData.rewardBps = uint16(_rewardBps);
        brrData.rebateBps = uint16(_rebateBps);

        emit BRRUpdated(_rewardBps, _rebateBps, _burnBps);
    }

    function setFeePool(address _feePool) external onlyDaoOperator {
        require(_feePool != address(0), "feePool 0");
        feePool = _feePool;

        emit FeePoolUpdated(_feePool);
    }

    /// @dev handleFees function is called per trade on kyberNetwork
    /// @dev unless the trade is not involving any fees.
    /// @param token Token currency of fees
    /// @param rebateWallets a list of rebate wallets that will get rebate for this trade.
    /// @param rebateBpsPerWallet percentage of rebate for each wallet, out of total rebate.
    /// @param platformWallet Wallet address that will receive the platfrom fee.
    /// @param platformFee Fee amount (in wei) the platfrom wallet is entitled to.
    /// @param networkFee Fee amount (in wei) to be allocated for BRR
    function handleFees(
        IERC20 token,
        address[] calldata rebateWallets,
        uint256[] calldata rebateBpsPerWallet,
        address platformWallet,
        uint256 platformFee,
        uint256 networkFee
    ) external payable override nonReentrant {
        require(token == ETH_TOKEN_ADDRESS, "token not eth");
        require(msg.value == platformFee.add(networkFee), "msg.value != total fees");

        // handle platform fee
        feePerPlatformWallet[platformWallet] = feePerPlatformWallet[platformWallet].add(
            platformFee
        );

        if (networkFee == 0) {
            // only platform fee paid
            totalPayoutBalance = totalPayoutBalance.add(platformFee);
            emit FeeDistributed(
                ETH_TOKEN_ADDRESS,
                msg.sender,
                platformWallet,
                platformFee,
                0,
                0,
                rebateWallets,
                rebateBpsPerWallet,
                0
            );
            return;
        }

        BRRWei memory brrAmounts;

        // Decoding BRR data
        (brrAmounts.rewardWei, brrAmounts.fullRebateWei) = getRRWeiValues(networkFee);
        brrAmounts.paidRebateWei = updateRebateValues(
            brrAmounts.fullRebateWei,
            rebateWallets,
            rebateBpsPerWallet
        );
        brrAmounts.burnWei = networkFee.sub(brrAmounts.rewardWei).sub(brrAmounts.paidRebateWei);
        // update total balance of rebates & platform fee
        totalPayoutBalance = totalPayoutBalance.add(platformFee).add(brrAmounts.paidRebateWei);

        //TODO: transfer reward to fee pool
        (bool success, ) = feePool.call{value: brrAmounts.rewardWei}("");
        require(success, "send fee failed");

        emit FeeDistributed(
            ETH_TOKEN_ADDRESS,
            msg.sender,
            platformWallet,
            platformFee,
            brrAmounts.rewardWei,
            brrAmounts.paidRebateWei,
            rebateWallets,
            rebateBpsPerWallet,
            brrAmounts.burnWei
        );
    }

    /// @dev claim rebate per reserve wallet. called by any address
    /// @param rebateWallet the wallet to claim rebates for. 
    /// @dev Total accumulated rebate sent to this wallet.
    /// @return amountWei amount of rebate claimed
    function claimReserveRebate(address rebateWallet)
        external
        override
        nonReentrant
        returns (uint256 amountWei)
    {
        require(rebatePerWallet[rebateWallet] > 1, "no rebate to claim");
        // Get total amount of rebate accumulated
        amountWei = rebatePerWallet[rebateWallet].sub(1);

        // redundant check, can't happen
        assert(totalPayoutBalance >= amountWei);
        totalPayoutBalance = totalPayoutBalance.sub(amountWei);

        rebatePerWallet[rebateWallet] = 1; // avoid zero to non zero storage cost

        // send rebate to rebate wallet
        (bool success, ) = rebateWallet.call{value: amountWei}("");
        require(success, "rebate transfer failed");

        emit RebatePaid(rebateWallet, ETH_TOKEN_ADDRESS, amountWei);

        return amountWei;
    }

    /// @dev implement so this contract is not marked as abstract
    function claimStakerReward(
        address, /*staker*/
        uint256 /*epoch*/
    ) external override returns (uint256) {
        revert();
    }

    /// @dev claim accumulated fee per platform wallet. Called by any address
    /// @param platformWallet the wallet to claim fee for.
    /// @dev Total accumulated fee sent to this wallet.
    /// @return amountWei amount of fee claimed
    function claimPlatformFee(address platformWallet)
        external
        override
        nonReentrant
        returns (uint256 amountWei)
    {
        require(feePerPlatformWallet[platformWallet] > 1, "no fee to claim");
        // Get total amount of fees accumulated
        amountWei = feePerPlatformWallet[platformWallet].sub(1);

        // redundant check, can't happen
        assert(totalPayoutBalance >= amountWei);
        totalPayoutBalance = totalPayoutBalance.sub(amountWei);

        feePerPlatformWallet[platformWallet] = 1; // avoid zero to non zero storage cost

        (bool success, ) = platformWallet.call{value: amountWei}("");
        require(success, "platform fee transfer failed");

        emit PlatformFeePaid(platformWallet, ETH_TOKEN_ADDRESS, amountWei);
        return amountWei;
    }

    /// @dev Allow to set kyberNetworkProxy address by daoOperator
    /// @param _newProxy new kyberNetworkProxy contract
    function setKyberProxy(IKyberProxy _newProxy) external onlyDaoOperator {
        require(_newProxy != IKyberProxy(0), "kyberNetworkProxy 0");
        if (_newProxy != kyberProxy) {
            kyberProxy = _newProxy;
            emit KyberProxyUpdated(_newProxy);
        }
    }

    /// @dev set knc sanity rate contract and amount wei to burn
    /// @param _sanityRate new sanity rate contract
    /// @param _weiToBurn new amount of wei to burn
    function setBurnConfigParams(ISanityRate _sanityRate, uint256 _weiToBurn)
        external
        onlyDaoOperator
    {
        require(_weiToBurn > 0, "_weiToBurn is 0");

        if (sanityRateContract.length == 0 || (_sanityRate != sanityRateContract[0])) {
            // it is a new sanity rate contract
            if (sanityRateContract.length == 0) {
                sanityRateContract.push(_sanityRate);
            } else {
                sanityRateContract.push(sanityRateContract[0]);
                sanityRateContract[0] = _sanityRate;
            }
        }

        weiToBurn = _weiToBurn;

        emit BurnConfigSet(_sanityRate, _weiToBurn);
    }

    /// @dev Burn knc. The burn amount is limited. Forces block delay between burn calls.
    /// @dev only none ontract can call this function
    /// @return kncBurnAmount amount of knc burned
    function burnKnc() external onlyNonContract returns (uint256 kncBurnAmount) {
        // check if current block > last burn block number + num block interval
        require(block.number > lastBurnBlock + burnBlockInterval, "wait more blocks to burn");

        // update last burn block number
        lastBurnBlock = block.number;

        // Get amount to burn, if greater than weiToBurn, burn only weiToBurn per function call.
        uint256 balance = address(this).balance;

        // redundant check, can't happen
        assert(balance >= totalPayoutBalance);
        uint256 srcAmount = balance.sub(totalPayoutBalance);
        srcAmount = srcAmount > weiToBurn ? weiToBurn : srcAmount;

        // Get rate
        uint256 kyberEthKncRate =
            kyberProxy.getExpectedRateAfterFee(ETH_TOKEN_ADDRESS, knc, srcAmount, 0, "");
        validateEthToKncRateToBurn(kyberEthKncRate);

        // Buy some knc and burn
        kncBurnAmount = kyberProxy.swapEtherToToken{value: srcAmount}(knc, kyberEthKncRate);

        require(IBurnableToken(address(knc)).burn(kncBurnAmount), "knc burn failed");

        emit KncBurned(kncBurnAmount, ETH_TOKEN_ADDRESS, srcAmount);
        return kncBurnAmount;
    }

    /// @notice should be called off chain
    /// @dev returns list of sanity rate contracts
    /// @dev index 0 is currently used contract address, indexes > 0 are older versions
    function getSanityRateContracts() external view returns (ISanityRate[] memory sanityRates) {
        sanityRates = sanityRateContract;
    }

    /// @dev return latest knc/eth rate from sanity rate contract
    function getLatestSanityRate() external view returns (uint256 kncToEthSanityRate) {
        if (sanityRateContract.length > 0 && sanityRateContract[0] != ISanityRate(0)) {
            kncToEthSanityRate = sanityRateContract[0].latestAnswer();
        } else {
            kncToEthSanityRate = 0;
        }
    }

    function readBRRData() external view returns (uint256 rewardBps, uint256 rebateBps) {
        rewardBps = uint256(brrData.rewardBps);
        rebateBps = uint256(brrData.rebateBps);
    }

    function updateRebateValues(
        uint256 rebateWei,
        address[] memory rebateWallets,
        uint256[] memory rebateBpsPerWallet
    ) internal returns (uint256 totalRebatePaidWei) {
        uint256 totalRebateBps;
        uint256 walletRebateWei;

        for (uint256 i = 0; i < rebateWallets.length; i++) {
            require(rebateWallets[i] != address(0), "rebate wallet address 0");

            walletRebateWei = rebateWei.mul(rebateBpsPerWallet[i]).div(BPS);
            rebatePerWallet[rebateWallets[i]] = rebatePerWallet[rebateWallets[i]].add(
                walletRebateWei
            );

            // a few wei could be left out due to rounding down. so count only paid wei
            totalRebatePaidWei = totalRebatePaidWei.add(walletRebateWei);
            totalRebateBps = totalRebateBps.add(rebateBpsPerWallet[i]);
        }
        require(totalRebateBps <= BPS, "totalRebateBps > 100%");
    }

    function getRRWeiValues(uint256 rrAmountWei)
        internal
        view
        returns (uint256 rewardWei, uint256 rebateWei)
    {
        // Decoding BRR data
        uint256 rewardInBps = uint256(brrData.rewardBps);
        uint256 rebateInBps = uint256(brrData.rebateBps);

        rebateWei = rrAmountWei.mul(rebateInBps).div(BPS);
        rewardWei = rrAmountWei.mul(rewardInBps).div(BPS);
    }

    function validateEthToKncRateToBurn(uint256 rateEthToKnc) internal view {
        require(rateEthToKnc <= MAX_RATE, "ethToKnc rate out of bounds");
        require(rateEthToKnc > 0, "ethToKnc rate is 0");
        require(sanityRateContract.length > 0, "no sanity rate contract");
        require(sanityRateContract[0] != ISanityRate(0), "sanity rate is 0x0, burning is blocked");

        // get latest knc/eth rate from sanity contract
        uint256 kncToEthRate = sanityRateContract[0].latestAnswer();
        require(kncToEthRate > 0, "sanity rate is 0");
        require(kncToEthRate <= MAX_RATE, "sanity rate out of bounds");

        uint256 sanityEthToKncRate = PRECISION.mul(PRECISION).div(kncToEthRate);

        // rate shouldn't be SANITY_RATE_DIFF_BPS lower than sanity rate
        require(
            rateEthToKnc.mul(BPS) >= sanityEthToKncRate.mul(BPS.sub(SANITY_RATE_DIFF_BPS)),
            "kyberNetwork eth to knc rate too low"
        );
    }
}