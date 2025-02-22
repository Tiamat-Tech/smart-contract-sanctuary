// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.6.0 <=0.8.9;
pragma experimental ABIEncoderV2;
import "./interfaces/IWETH.sol";
import "./interfaces/IBurnableToken.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ISwapContract.sol";
import "./interfaces/IAugustusSwapper.sol";
import "./interfaces/ITokenTransferProxy.sol";
import "./interfaces/IParaswap.sol";
import "./interfaces/lib/Utils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/lib/SafeERC20.sol";
import "hardhat/console.sol";
//skypools - needed for address => tokenBalance
import "./LPToken.sol";

contract SwapContract is Ownable, ReentrancyGuard, ISwapContract {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct spPendingTx {
        bytes32 SwapID; //swap hash for identification of this swap.
        string DestAddr; //destination BTC address for the swap
        address RefundAddr; //refund address on evm source chain for if the swap fails.
        uint256 AmountWBTC; //outbound amount for this swap.
        uint256 Timestamp; // block timestamp that is set by EVM
    }
    uint256 public expirationTime;

    mapping(uint256 => spPendingTx) public spPendingTXs; //index => pending TX object
    //spPendingTx[] spPendingTXs;
    uint256 public swapCount;
    uint256 public oldestActiveIndex;

    mapping(address => bool) public whitelist;

    address public immutable BTCT_ADDR;
    address public immutable lpToken;

    uint8 public churnedInCount;
    uint8 public tssThreshold;
    uint8 public nodeRewardsRatio;
    uint8 public depositFeesBPS;
    uint8 public withdrawalFeeBPS;
    uint256 public lockedLPTokensForNode;
    uint256 public feesLPTokensForNode;
    uint256 public initialExchangeRate;

    uint256 private immutable convertScale;
    uint256 private immutable lpDecimals;

    mapping(address => uint256) private floatAmountOf;
    mapping(bytes32 => bool) private used; //used TX

    // Node lists
    mapping(address => bytes32) private nodes;
    mapping(address => bool) private isInList;
    address[] private nodeAddrs;

    //skypools - token balance - call using tokens[token address][user address] to get uint256 balance - see function balanceOf
    mapping(address => mapping(address => uint256)) public tokens;
    //keep track of ether in tokens[][]
    address constant ETHER =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address constant paraswapAddress =
        0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;
    address public immutable wETH;

    /**
     * Events
     */
    event Swap(address from, address to, uint256 amount);
    event Withdraw(
        address token,
        address user,
        uint256 amount,
        uint256 balance,
        uint256 Timestamp
    );
    event Deposit(
        address token,
        address user,
        uint256 amount,
        uint256 balance,
        uint256 Timestamp
    );
    event RewardsCollection(
        address feesToken,
        uint256 rewards,
        uint256 amountLPTokensForNode,
        uint256 currentPriceLP
    );

    event IssueLPTokensForFloat(
        address to,
        uint256 amountOfFloat,
        uint256 amountOfLP,
        uint256 currentPriceLP,
        uint256 depositFees,
        bytes32 txid
    );

    event BurnLPTokensForFloat(
        address token,
        uint256 amountOfLP,
        uint256 amountOfFloat,
        uint256 currentPriceLP,
        uint256 withdrawal,
        bytes32 txid
    );

    event SwapTokensToBTC(
        bytes32 SwapID,
        string DestAddr,
        address RefundAddr,
        uint256 AmountWBTC,
        uint256 Timestamp
    );

    event SetExpirationTime(uint256 ExpirationTime, uint256 Timestamp);

    event DistributeNodeRewards(uint256 rewardLPTsForNodes);

    modifier priceCheck() {
        uint256 beforePrice = getCurrentPriceLP();
        _;
        require(getCurrentPriceLP() >= beforePrice, "Invalid LPT price");
    }

    constructor(
        address _lpToken,
        address _btct,
        address _wETH,
        uint256 _existingBTCFloat
    ) {
        //set default expiration time for pending TX
        expirationTime = 172800; //2 days
        //init latest removed index and swapCount
        oldestActiveIndex = 0;
        swapCount = 0;
        //set address for wETH
        wETH = _wETH;
        // Set lpToken address
        lpToken = _lpToken;
        // Set initial lpDecimals of LP token
        lpDecimals = 10**IERC20(_lpToken).decimals();
        // Set BTCT address
        BTCT_ADDR = _btct;
        // Set nodeRewardsRatio
        nodeRewardsRatio = 66;
        // Set depositFeesBPS
        depositFeesBPS = 50;
        // Set withdrawalFeeBPS
        withdrawalFeeBPS = 20;
        // Set convertScale
        convertScale = 10**(IERC20(_btct).decimals() - 8);
        // Set initialExchangeRate
        initialExchangeRate = 10**IERC20(_lpToken).decimals();
        // Set lockedLPTokensForNode
        lockedLPTokensForNode = 0;
        // Set feesLPTokensForNode
        feesLPTokensForNode = 0;
        // Set whitelist addresses
        whitelist[_btct] = true;
        whitelist[_lpToken] = true;
        whitelist[address(0)] = true;
        floatAmountOf[address(0)] = _existingBTCFloat;
    }

    /**
     * Transfer part
     */

    /// @dev singleTransferERC20 sends tokens from contract.
    /// @param _destToken The address of target token.
    /// @param _to The address of recipient.
    /// @param _amount The amount of tokens.
    /// @param _totalSwapped The amount of swap.
    /// @param _rewardsAmount The fees that should be paid.
    /// @param _redeemedFloatTxIds The txids which is for recording.
    function singleTransferERC20(
        address _destToken,
        address _to,
        uint256 _amount,
        uint256 _totalSwapped,
        uint256 _rewardsAmount,
        bytes32[] memory _redeemedFloatTxIds
    ) external override onlyOwner returns (bool) {
        require(whitelist[_destToken], "_destToken is not whitelisted");
        require(
            _destToken != address(0),
            "_destToken should not be address(0)"
        );
        address _feesToken;
        if (_totalSwapped > 0) {
            _swap(address(0), BTCT_ADDR, _totalSwapped);
        } else if (_totalSwapped == 0) {
            _feesToken = BTCT_ADDR;
        }
        if (_destToken == lpToken) {
            _feesToken = lpToken;
        }
        _rewardsCollection(_feesToken, _rewardsAmount);
        _addUsedTxs(_redeemedFloatTxIds);
        _safeTransfer(_destToken, _to, _amount);
        return true;
    }

    /// @dev multiTransferERC20TightlyPacked sends tokens from contract.
    /// @param _destToken The address of target token.
    /// @param _addressesAndAmounts The address of recipient and amount.
    /// @param _totalSwapped The amount of swap.
    /// @param _rewardsAmount The fees that should be paid.
    /// @param _redeemedFloatTxIds The txids which is for recording.
    function multiTransferERC20TightlyPacked(
        address _destToken,
        bytes32[] memory _addressesAndAmounts,
        uint256 _totalSwapped,
        uint256 _rewardsAmount,
        bytes32[] memory _redeemedFloatTxIds
    ) external override onlyOwner returns (bool) {
        require(whitelist[_destToken], "_destToken is not whitelisted");
        require(
            _destToken != address(0),
            "_destToken should not be address(0)"
        );
        address _feesToken;
        if (_totalSwapped > 0) {
            _swap(address(0), BTCT_ADDR, _totalSwapped);
        } else if (_totalSwapped == 0) {
            _feesToken = BTCT_ADDR;
        }
        if (_destToken == lpToken) {
            _feesToken = lpToken;
        }
        _rewardsCollection(_feesToken, _rewardsAmount);
        _addUsedTxs(_redeemedFloatTxIds);
        for (uint256 i = 0; i < _addressesAndAmounts.length; i++) {
            _safeTransfer(
                _destToken,
                address(uint160(uint256(_addressesAndAmounts[i]))),
                uint256(uint96(bytes12(_addressesAndAmounts[i])))
            );
        }
        return true;
    }

    /// @dev collectSwapFeesForBTC collects fees in the case of swap BTCT to BTC.
    /// @param _destToken The address of target token.
    /// @param _incomingAmount The spent amount. (BTCT)
    /// @param _minerFee The miner fees of BTC transaction.
    /// @param _rewardsAmount The fees that should be paid.
    function collectSwapFeesForBTC(
        address _destToken,
        uint256 _incomingAmount,
        uint256 _minerFee,
        uint256 _rewardsAmount
    ) external override onlyOwner returns (bool) {
        require(_destToken == address(0), "_destToken should be address(0)");
        address _feesToken = BTCT_ADDR;
        if (_incomingAmount > 0) {
            uint256 swapAmount = _incomingAmount.sub(_rewardsAmount).sub(
                _minerFee
            );
            _swap(BTCT_ADDR, address(0), swapAmount.add(_minerFee));
        } else if (_incomingAmount == 0) {
            _feesToken = address(0);
        }
        _rewardsCollection(_feesToken, _rewardsAmount);
        return true;
    }

    /**
     * Float part
     */
    /// @dev recordIncomingFloat mints LP token.
    /// @param _token The address of target token.
    /// @param _addressesAndAmountOfFloat The address of recipient and amount.
    /// @param _zerofee The flag to accept zero fees.
    /// @param _txid The txids which is for recording.
    function recordIncomingFloat(
        address _token,
        bytes32 _addressesAndAmountOfFloat,
        bool _zerofee,
        bytes32 _txid
    ) external override onlyOwner priceCheck returns (bool) {
        require(whitelist[_token], "_token is invalid");
        require(
            _issueLPTokensForFloat(
                _token,
                _addressesAndAmountOfFloat,
                _zerofee,
                _txid
            )
        );
        return true;
    }

    /// @dev recordOutcomingFloat burns LP token.
    /// @param _token The address of target token.
    /// @param _addressesAndAmountOfLPtoken The address of recipient and amount.
    /// @param _minerFee The miner fees of BTC transaction.
    /// @param _txid The txid which is for recording.
    function recordOutcomingFloat(
        address _token,
        bytes32 _addressesAndAmountOfLPtoken,
        uint256 _minerFee,
        bytes32 _txid
    ) external override onlyOwner priceCheck returns (bool) {
        require(whitelist[_token], "_token is invalid");
        require(
            _burnLPTokensForFloat(
                _token,
                _addressesAndAmountOfLPtoken,
                _minerFee,
                _txid
            )
        );
        return true;
    }

    /// @dev distributeNodeRewards sends rewards for Nodes.
    function distributeNodeRewards() external override returns (bool) {
        // Reduce Gas
        uint256 rewardLPTsForNodes = lockedLPTokensForNode.add(
            feesLPTokensForNode
        );
        require(
            rewardLPTsForNodes > 0,
            "totalRewardLPsForNode is not positive"
        );
        bytes32[] memory nodeList = getActiveNodes();
        uint256 totalStaked = 0;
        for (uint256 i = 0; i < nodeList.length; i++) {
            totalStaked = totalStaked.add(
                uint256(uint96(bytes12(nodeList[i])))
            );
        }
        IBurnableToken(lpToken).mint(address(this), lockedLPTokensForNode);
        for (uint256 i = 0; i < nodeList.length; i++) {
            IBurnableToken(lpToken).transfer(
                address(uint160(uint256(nodeList[i]))),
                rewardLPTsForNodes
                    .mul(uint256(uint96(bytes12(nodeList[i]))))
                    .div(totalStaked)
            );
        }
        emit DistributeNodeRewards(rewardLPTsForNodes);
        lockedLPTokensForNode = 0;
        feesLPTokensForNode = 0;
        return true;
    }

    /**
     * Skypools part
     */

    /// @dev Record SkyPools TX - allocate tokens from float to user in tokens[][]
    /// @param _to The address of recipient.
    /// @param _totalSwapped The amount of swap amount.
    /// @param _rewardsAmount The fees that should be paid.
    /// @param _usedTxIds The txids which is for recording this function.
    function recordSkyPoolsTX(
        address _to,
        uint256 _totalSwapped,
        uint256 _rewardsAmount,
        bytes32[] memory _usedTxIds
    ) external onlyOwner returns (bool) {
        require(_totalSwapped != 0, "_totalSwapped must be non zero");
        require(_rewardsAmount != 0, "_rewardsAmount must be non zero");

        _swap(address(0), BTCT_ADDR, _totalSwapped);

        tokens[BTCT_ADDR][_to] = tokens[BTCT_ADDR][_to].add(_totalSwapped);

        _rewardsCollection(address(0), _rewardsAmount);

        _addUsedTxs(_usedTxIds);

        return true;
    }

    /// @dev balanceOf - return user balance for given token and user for skypools
    /// @param _token The address of target token.
    /// @param _user The address of target user.
    function balanceOf(address _token, address _user)
        public
        view
        returns (uint256)
    {
        return tokens[_token][_user];
    }

    /// @dev spFlow1SimpleSwap - FLOW 1 - execute paraswap TX using simpleSwap, ending tokens sent DIRECTLY to user's wallet
    /// @param _data A struct containing the data for simpleSwap, from the paraswap lib.
    function spFlow1SimpleSwap(Utils.SimpleData calldata _data)
        external
        nonReentrant
    {
        require(
            _data.beneficiary == msg.sender,
            "You can only execute swaps to your own address"
        );

        require(
            tokens[_data.fromToken][_data.beneficiary] >= _data.fromAmount,
            "Balance is not sufficient"
        );
        require(
            _data.fromToken == BTCT_ADDR,
            "fromToken must be the required BTCt token"
        );
        _doSimpleSwap(_data); //no received amount, tokens to go user's wallet

        tokens[_data.fromToken][_data.beneficiary] = tokens[_data.fromToken][
            _data.beneficiary
        ].sub(_data.fromAmount);
    }

    /// @dev spFlow1Uniswap - FLOW 1 - execute paraswap TX using uniswap, ending tokens sent to users allocation in tokens[][] mapping
    /// @param _fork - BOOL to determine if using swapOnUniswap or swapOnUniswapFork paraswap contract methods
    /// @param _factory - param for swapOnUniswapFork
    /// @param _initCode - param for swapOnUniswapFork
    /// @param _amountIn - param for swapOnUniswapFork or swapOnUniswap
    /// @param _amountOutMin - param for swapOnUniswapFork or swapOnUniswap
    /// @param _path - param for swapOnUniswapFork or swapOnUniswap
    function spFlow1Uniswap(
        bool _fork,
        address _factory,
        bytes32 _initCode,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path
    ) external nonReentrant returns (uint256 receivedAmount){
        address fromToken = _path[0];
        address endToken = _path[_path.length - 1];

        require(
            tokens[fromToken][msg.sender] >= _amountIn,
            "Balance is not sufficient"
        );

        require(fromToken == BTCT_ADDR, "Must swap from BTC token");
        require(endToken != BTCT_ADDR, "Ending token must be wBTC");
        require(endToken != ETHER, "Use path wBTC -> wETH");

        uint256 preSwapBalance = IERC20(endToken).balanceOf(address(this));

        tokens[fromToken][msg.sender] = tokens[fromToken][msg.sender].sub(
            _amountIn
        );

        //do swap
        if (_fork) {
            _doUniswapFork(
                _factory,
                _initCode,
                _amountIn,
                _amountOutMin,
                _path
            );
        } else {
            _doUniswap(_amountIn, _amountOutMin, _path);
        }

        receivedAmount = IERC20(endToken).balanceOf(address(this)).sub(
            preSwapBalance
        );

        require(
            receivedAmount >= _amountOutMin,
            "Received amount insufficient"
        );
        require(receivedAmount != 0);

        tokens[endToken][msg.sender] = tokens[endToken][msg.sender].add(
            receivedAmount
        );

        return receivedAmount;
    }

    /// @dev spFlow2Uniswap - FLOW 1 - execute paraswap TX using uniswap, ending tokens sent to users allocation in tokens[][] mapping
    /// @param _fork - BOOL to determine if using swapOnUniswap or swapOnUniswapFork paraswap contract methods
    /// @param _factory - param for swapOnUniswapFork
    /// @param _initCode - param for swapOnUniswapFork
    /// @param _amountIn - param for swapOnUniswapFork or swapOnUniswap
    /// @param _amountOutMin - param for swapOnUniswapFork or swapOnUniswap
    /// @param _path - param for swapOnUniswapFork or swapOnUniswap
    function spFlow2Uniswap(
        string calldata _destinationAddressForBTC,
        bool _fork,
        address _factory,
        bytes32 _initCode,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path
    ) external nonReentrant returns (uint256 receivedAmount) {
        address fromToken = _path[0];
        address endToken = _path[_path.length - 1];

        require(
            tokens[fromToken][msg.sender] >= _amountIn,
            "Balance is not sufficient"
        );
        require(fromToken != BTCT_ADDR, "Must swap from BTC token");
        require(fromToken != ETHER, "Use path wETH -> wBTC");
        require(endToken == BTCT_ADDR, "Must swap to BTC token");

        uint256 preSwapBalance = IERC20(endToken).balanceOf(address(this));

        tokens[fromToken][msg.sender] = tokens[fromToken][msg.sender].sub(
            _amountIn
        );

        //do swap
        if (_fork) {
            _doUniswapFork(
                _factory,
                _initCode,
                _amountIn,
                _amountOutMin,
                _path
            );
        } else {
            _doUniswap(_amountIn, _amountOutMin, _path);
        }

        uint256 receivedAmount = IERC20(endToken).balanceOf(address(this)).sub(
            preSwapBalance
        );

        require(
            receivedAmount >= _amountOutMin,
            "Received amount insufficient"
        );
        require(receivedAmount != 0);

        tokens[endToken][address(this)] = tokens[endToken][address(this)].add(
            receivedAmount
        );

        _spRecordPendingTx(_destinationAddressForBTC, receivedAmount);

        return receivedAmount;
    }

    /// @dev spParaSwapToken2BTC - FLOW 2 -> swap ERC20 -> wBTC
    /// @param _destinationAddressForBTC The BTC address to send BTC to.
    /// @param _data simpleData from paraswap API call, param for simpleSwap
    function spFlow2SimpleSwap(
        string calldata _destinationAddressForBTC,
        Utils.SimpleData calldata _data
    ) external nonReentrant returns (uint256 receivedAmount) {
        //bytes32 destBytes32 = _stringToBytes32(destinationAddressForBTC);
        //console.log("Converted to bytes32 and back to String:",_bytes32ToString(destBytes32));

        require(_data.fromToken != BTCT_ADDR, "Must swap from BTC token");
        require(_data.toToken == BTCT_ADDR, "Must swap to BTC token");
        require(_data.beneficiary == address(this), "Beneficiary must be this contract");
        require(
            tokens[_data.fromToken][msg.sender] >= _data.fromAmount,
            "Balance is not sufficient"
        );

        uint256 preSwapBalance = IERC20(_data.toToken).balanceOf(address(this));

        tokens[_data.fromToken][msg.sender] = tokens[_data.fromToken][
            msg.sender
        ].sub(_data.fromAmount);

        _doSimpleSwap(_data);

        uint256 receivedAmount = IERC20(_data.toToken)
            .balanceOf(address(this))
            .sub(preSwapBalance);

        require(
            receivedAmount >= _data.expectedAmount,
            "Received amount insufficient"
        );
        require(receivedAmount != 0);

        tokens[_data.toToken][address(this)] = tokens[_data.toToken][
            address(this)
        ].add(receivedAmount);

        _spRecordPendingTx(_destinationAddressForBTC, receivedAmount);

        return receivedAmount;
    }

    /// @dev _doUniswapFork - performs paraswap transaction - BALANCE & TOKEN CHECKS MUST OCCUR BEFORE CALLING THIS
    /// @param _factory - param for swapOnUniswapFork
    /// @param _initCode - param for swapOnUniswapFork
    /// @param _amountIn - param for swapOnUniswapFork
    /// @param _amountOutMin - param for swapOnUniswapFork
    /// @param _path - param for swapOnUniswapFork
    function _doUniswapFork(
        address _factory,
        bytes32 _initCode,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path
    ) internal {
        address fromToken = _path[0];

        address proxy = IAugustusSwapper(paraswapAddress)
            .getTokenTransferProxy();

        IERC20(fromToken).safeIncreaseAllowance(proxy, _amountIn);

        IParaswap(paraswapAddress).swapOnUniswapFork(
            _factory,
            _initCode,
            _amountIn,
            _amountOutMin,
            _path
        );
    }

    /// @dev _doUniswap - performs paraswap transaction - BALANCE & TOKEN CHECKS MUST OCCUR BEFORE CALLING THIS
    /// @param _amountIn - param for swapOnUniswap
    /// @param _amountOutMin - param for swapOnUniswap
    /// @param _path - param for swapOnUniswap
    function _doUniswap(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path
    ) internal {
        address fromToken = _path[0];

        address proxy = IAugustusSwapper(paraswapAddress)
            .getTokenTransferProxy();

        IERC20(fromToken).safeIncreaseAllowance(proxy, _amountIn);

        IParaswap(paraswapAddress).swapOnUniswap(
            _amountIn,
            _amountOutMin,
            _path
        );
    }

    /// @dev _doSimpleSwap - performs paraswap transaction - BALANCE & TOKEN CHECKS MUST OCCUR BEFORE CALLING THIS
    /// @param _data data from API call that is ready to be sent to paraswap interface
    function _doSimpleSwap(Utils.SimpleData calldata _data) internal {
        address proxy = IAugustusSwapper(paraswapAddress)
            .getTokenTransferProxy();

        IERC20(_data.fromToken).safeIncreaseAllowance(proxy, _data.fromAmount);

        IParaswap(paraswapAddress).simpleSwap(_data);
    }

    /// @dev _spRecordPendingTx - hash a unique swap ID, and add it to the array of pending TXs, and then emit event
    /// @param _destinationAddressForBTC The BTC address to send BTC to.
    /// @param _btctAmount amount in BTC decimal 8.
    function _spRecordPendingTx(
        string calldata _destinationAddressForBTC,
        uint256 _btctAmount
    ) internal {
        //hash TX data for unique ID
        bytes32 ID = keccak256(
            abi.encodePacked(
                BTCT_ADDR, //specific to current chain
                swapCount,
                _destinationAddressForBTC,
                _btctAmount,
                block.timestamp
            )
        );

        spPendingTXs[swapCount] = spPendingTx(
            ID,
            _destinationAddressForBTC,
            msg.sender,
            _btctAmount,
            block.timestamp
        );

        //clean up expired TXs
        _spCleanUpOldTXs();

        swapCount = swapCount.add(1); //increment TX count after cleaning up pending TXs to not loop over next empty index

        emit SwapTokensToBTC(
            ID,
            _destinationAddressForBTC,
            msg.sender,
            _btctAmount,
            block.timestamp
        );
    }

    /// @dev setExpirationTime - allow node to adjust expiration time
    /// @param _expirationTime new expiration time
    function _setExpirationTime(uint256 _expirationTime) internal {
        expirationTime = _expirationTime;
        emit SetExpirationTime(_expirationTime, block.timestamp);
    }

    /// @dev spGetPendingSwaps - returns array of pending swaps
    /// @return data - returns array of pending swap struct objects
    function spGetPendingSwaps()
        external
        view
        returns (spPendingTx[] memory data)
    {
        //require(swapCount != 0);
        
        uint256 index = 0;
        data = new spPendingTx[](swapCount.sub(oldestActiveIndex));

        for (uint256 i = oldestActiveIndex.add(1); i <= swapCount; i++) {
            data[index] = spPendingTXs[index.add(oldestActiveIndex)];
            index = index.add(1);
        } 

        return data;        
    }

    /// @dev _spCleanUpOldTXs - call when executing flow 2 swaps, cleans up expired TXs and moves the indices
    function _spCleanUpOldTXs() internal {
        uint256 current = block.timestamp;
        for (uint256 i = oldestActiveIndex; i <= swapCount; i++) {
            if (spPendingTXs[i].Timestamp.add(expirationTime) < current) {
                tokens[BTCT_ADDR][address(this)] = tokens[BTCT_ADDR][
                    address(this)
                ].sub(spPendingTXs[i].AmountWBTC);
                delete spPendingTXs[i];
                oldestActiveIndex = i.add(1); //next index to be deleted
            }
        }
    }

    /// @dev spCleanUpOldTXs - call when executing flow 2 swaps, cleans up expired TXs and moves the indices
    /// @param _loopCount - max times the loop will run
    function spCleanUpOldTXs(uint256 _loopCount) external {
        uint256 max = oldestActiveIndex.add(_loopCount);

        if (max >= swapCount) {
            max = swapCount;
        }

        uint256 current = block.timestamp;
        for (uint256 i = oldestActiveIndex; i <= max; i++) {
            if (spPendingTXs[i].Timestamp.add(expirationTime) < current) {
                tokens[BTCT_ADDR][address(this)] = tokens[BTCT_ADDR][
                    address(this)
                ].sub(spPendingTXs[i].AmountWBTC);
                delete spPendingTXs[i];
                oldestActiveIndex = i.add(1);
            }
        }
    }

    /// @dev spDeposit - ERC-20 ONLY - users deposit ERC-20 tokens, balances to be stored in tokens[][]
    /// @param _token The address of the ERC-20 token contract.
    /// @param _amount amount to be deposited.
    function spDeposit(address _token, uint256 _amount)
        external
        payable
        nonReentrant
    {
        if (msg.value == 0) {
            require(_token != ETHER);
            require(_token != BTCT_ADDR);

            uint256 initBalance = IERC20(_token).balanceOf(address(this));

            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

            uint256 endingBalance = IERC20(_token).balanceOf(address(this));

            uint256 received = endingBalance.sub(initBalance);

            tokens[_token][msg.sender] = tokens[_token][msg.sender].add(
                received
            );

            emit Deposit(
                _token,
                msg.sender,
                received,
                tokens[_token][msg.sender],
                block.timestamp
            );
        } else {
            require(msg.value > 0);
            //swap to wETH tokens - contract now holds wETH instead of ether
            IWETH(wETH).deposit{value: msg.value}();

            tokens[wETH][msg.sender] = tokens[wETH][msg.sender].add(msg.value);

            emit Deposit(
                ETHER,
                msg.sender,
                msg.value,
                tokens[wETH][msg.sender],
                block.timestamp
            );
        }
    }

    /// @dev redeemEther for skypools - swap wETH for ether and send to user's wallet
    /// @param _amount amount to withdraw
    function redeemEther(uint256 _amount) external nonReentrant {
        require(tokens[wETH][msg.sender] >= _amount);
        IWETH(wETH).withdraw(_amount);
        tokens[wETH][msg.sender] = tokens[wETH][msg.sender].sub(_amount);
        address payable sender = payable(msg.sender);
        //sender.transfer(_amount);

        (bool sent, bytes memory data) = sender.call{value: _amount}("");

        require(sent);
        emit Withdraw(
            ETHER,
            msg.sender,
            _amount,
            tokens[wETH][msg.sender],
            block.timestamp
        );
    }

    receive() external payable {
        assert(msg.sender == wETH); // only accept ETH via fallback from the WETH contract
    }

    /// @dev redeemERC20Token for skypools - redeem erc20 token
    /// @param _token The address of target token.
    /// @param _amount The amount to withdraw - call with BTC decimals (8) for BTC
    function redeemERC20Token(address _token, uint256 _amount)
        external
        nonReentrant
    {
        require(tokens[_token][msg.sender] >= _amount, "Insufficient Balance");
        tokens[_token][msg.sender] = tokens[_token][msg.sender].sub(_amount);
        _safeTransfer(_token, msg.sender, _amount);

        emit Withdraw(
            _token,
            msg.sender,
            _amount,
            tokens[_token][msg.sender],
            block.timestamp
        );
    }

    /**
     * Life cycle part
     */

    /// @dev recordUTXOSweepMinerFee reduces float amount by collected miner fees.
    /// @param _minerFee The miner fees of BTC transaction.
    /// @param _txid The txid which is for recording.
    function recordUTXOSweepMinerFee(uint256 _minerFee, bytes32 _txid)
        public
        override
        onlyOwner
        returns (bool)
    {
        require(!isTxUsed(_txid), "The txid is already used");
        floatAmountOf[address(0)] = floatAmountOf[address(0)].sub(
            _minerFee,
            "BTC float amount insufficient"
        );
        _addUsedTx(_txid);
        return true;
    }

    /// @dev churn transfers contract ownership and set variables of the next TSS validator set.
    /// @param _newOwner The address of new Owner.
    /// @param _rewardAddressAndAmounts The reward addresses and amounts.
    /// @param _isRemoved The flags to remove node.
    /// @param _churnedInCount The number of next party size of TSS group.
    /// @param _tssThreshold The number of next threshold.
    /// @param _nodeRewardsRatio The number of rewards ratio for node owners
    /// @param _withdrawalFeeBPS The amount of wthdrawal fees.
    function churn(
        address _newOwner,
        bytes32[] memory _rewardAddressAndAmounts,
        bool[] memory _isRemoved,
        uint8 _churnedInCount,
        uint8 _tssThreshold,
        uint8 _nodeRewardsRatio,
        uint8 _withdrawalFeeBPS,
        uint256 _expirationTime //set to 0 to keep existing expiration time
    ) external override onlyOwner returns (bool) {
        require(
            _tssThreshold >= tssThreshold && _tssThreshold <= 2**8 - 1,
            "_tssThreshold should be >= tssThreshold"
        );
        require(
            _churnedInCount >= _tssThreshold + uint8(1),
            "n should be >= t+1"
        );
        require(
            _nodeRewardsRatio >= 0 && _nodeRewardsRatio <= 100,
            "_nodeRewardsRatio is not valid"
        );
        require(
            _withdrawalFeeBPS >= 0 && _withdrawalFeeBPS <= 100,
            "_withdrawalFeeBPS is invalid"
        );
        require(
            _rewardAddressAndAmounts.length == _isRemoved.length,
            "_rewardAddressAndAmounts and _isRemoved length do not match"
        );
        if (_expirationTime != 0) {
            _setExpirationTime(_expirationTime);
        }
        transferOwnership(_newOwner);
        // Update active node list
        for (uint256 i = 0; i < _rewardAddressAndAmounts.length; i++) {
            (address newNode, ) = _splitToValues(_rewardAddressAndAmounts[i]);
            _addNode(newNode, _rewardAddressAndAmounts[i], _isRemoved[i]);
        }
        bytes32[] memory nodeList = getActiveNodes();
        if (nodeList.length > 100) {
            revert("Stored node size should be <= 100");
        }
        churnedInCount = _churnedInCount;
        tssThreshold = _tssThreshold;
        nodeRewardsRatio = _nodeRewardsRatio;
        withdrawalFeeBPS = _withdrawalFeeBPS;
        return true;
    }

    /// @dev isTxUsed sends rewards for Nodes.
    /// @param _txid The txid which is for recording.
    function isTxUsed(bytes32 _txid) public view override returns (bool) {
        return used[_txid];
    }

    /// @dev getCurrentPriceLP returns the current exchange rate of LP token.
    function getCurrentPriceLP()
        public
        view
        override
        returns (uint256 nowPrice)
    {
        (uint256 reserveA, uint256 reserveB) = getFloatReserve(
            address(0),
            BTCT_ADDR
        );
        uint256 totalLPs = IBurnableToken(lpToken).totalSupply();
        // decimals of totalReserved == 8, lpDecimals == 8, decimals of rate == 8
        nowPrice = totalLPs == 0
            ? initialExchangeRate
            : (reserveA.add(reserveB)).mul(lpDecimals).div(
                totalLPs.add(lockedLPTokensForNode)
            );
        return nowPrice;
    }

    /// @dev getDepositFeeRate returns deposit fees rate
    /// @param _token The address of target token.
    /// @param _amountOfFloat The amount of float.
    function getDepositFeeRate(address _token, uint256 _amountOfFloat)
        public
        view
        override
        returns (uint256 depositFeeRate)
    {
        uint8 isFlip = _checkFlips(_token, _amountOfFloat);
        if (isFlip == 1) {
            depositFeeRate = _token == BTCT_ADDR ? depositFeesBPS : 0;
        } else if (isFlip == 2) {
            depositFeeRate = _token == address(0) ? depositFeesBPS : 0;
        }
    }

    /// @dev getFloatReserve returns float reserves
    /// @param _tokenA The address of target tokenA.
    /// @param _tokenB The address of target tokenB.
    function getFloatReserve(address _tokenA, address _tokenB)
        public
        view
        override
        returns (uint256 reserveA, uint256 reserveB)
    {
        (reserveA, reserveB) = (floatAmountOf[_tokenA], floatAmountOf[_tokenB]);
    }

    /// @dev getActiveNodes returns active nodes list (stakes and amount)
    function getActiveNodes() public view override returns (bytes32[] memory) {
        uint256 nodeCount = 0;
        uint256 count = 0;
        // Seek all nodes
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            if (nodes[nodeAddrs[i]] != 0x0) {
                nodeCount = nodeCount.add(1);
            }
        }
        bytes32[] memory _nodes = new bytes32[](nodeCount);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            if (nodes[nodeAddrs[i]] != 0x0) {
                _nodes[count] = nodes[nodeAddrs[i]];
                count = count.add(1);
            }
        }
        return _nodes;
    }

    /// @dev _issueLPTokensForFloat
    /// @param _token The address of target token.
    /// @param _transaction The recevier address and amount.
    /// @param _zerofee The flag to accept zero fees.
    /// @param _txid The txid which is for recording.
    function _issueLPTokensForFloat(
        address _token,
        bytes32 _transaction,
        bool _zerofee,
        bytes32 _txid
    ) internal returns (bool) {
        require(!isTxUsed(_txid), "The txid is already used");
        require(_transaction != 0x0, "The transaction is not valid");
        // Define target address which is recorded on the tx data (20 bytes)
        // Define amountOfFloat which is recorded top on tx data (12 bytes)
        (address to, uint256 amountOfFloat) = _splitToValues(_transaction);
        // Calculate the amount of LP token
        uint256 nowPrice = getCurrentPriceLP();
        uint256 amountOfLP = amountOfFloat.mul(lpDecimals).div(nowPrice);
        uint256 depositFeeRate = getDepositFeeRate(_token, amountOfFloat);
        uint256 depositFees = depositFeeRate != 0
            ? amountOfLP.mul(depositFeeRate).div(10000)
            : 0;

        if (_zerofee && depositFees != 0) {
            revert();
        }
        // Send LP tokens to LP
        IBurnableToken(lpToken).mint(to, amountOfLP.sub(depositFees));
        // Add deposit fees
        lockedLPTokensForNode = lockedLPTokensForNode.add(depositFees);
        // Add float amount
        _addFloat(_token, amountOfFloat);
        _addUsedTx(_txid);
        emit IssueLPTokensForFloat(
            to,
            amountOfFloat,
            amountOfLP,
            nowPrice,
            depositFees,
            _txid
        );
        return true;
    }

    /// @dev _burnLPTokensForFloat
    /// @param _token The address of target token.
    /// @param _transaction The address of sender and amount.
    /// @param _minerFee The miner fees of BTC transaction.
    /// @param _txid The txid which is for recording.
    function _burnLPTokensForFloat(
        address _token,
        bytes32 _transaction,
        uint256 _minerFee,
        bytes32 _txid
    ) internal returns (bool) {
        require(!isTxUsed(_txid), "The txid is already used");
        require(_transaction != 0x0, "The transaction is not valid");
        // Define target address which is recorded on the tx data (20bytes)
        // Define amountLP which is recorded top on tx data (12bytes)
        (address to, uint256 amountOfLP) = _splitToValues(_transaction);
        // Calculate the amount of LP token
        uint256 nowPrice = getCurrentPriceLP();
        // Calculate the amountOfFloat
        uint256 amountOfFloat = amountOfLP.mul(nowPrice).div(lpDecimals);
        uint256 withdrawalFees = amountOfFloat.mul(withdrawalFeeBPS).div(10000);
        require(
            amountOfFloat.sub(withdrawalFees) >= _minerFee,
            "Error: amountOfFloat.sub(withdrawalFees) < _minerFee"
        );
        uint256 withdrawal = amountOfFloat.sub(withdrawalFees).sub(_minerFee);
        (uint256 reserveA, uint256 reserveB) = getFloatReserve(
            address(0),
            BTCT_ADDR
        );
        if (_token == address(0)) {
            require(
                reserveA >= amountOfFloat.sub(withdrawalFees),
                "The float balance insufficient."
            );
        } else if (_token == BTCT_ADDR) {
            require(
                reserveB >= amountOfFloat.sub(withdrawalFees),
                "The float balance insufficient."
            );
        }
        // Collect fees before remove float
        _rewardsCollection(_token, withdrawalFees);
        // Remove float amount
        _removeFloat(_token, amountOfFloat);
        // Add txid for recording.
        _addUsedTx(_txid);
        // BTCT transfer if token address is BTCT_ADDR
        if (_token == BTCT_ADDR) {
            // _minerFee should be zero
            _safeTransfer(_token, to, withdrawal);
        }
        // Burn LP tokens
        require(IBurnableToken(lpToken).burn(amountOfLP));
        emit BurnLPTokensForFloat(
            to,
            amountOfLP,
            amountOfFloat,
            nowPrice,
            withdrawal,
            _txid
        );
        return true;
    }

    /// @dev _checkFlips checks whether the fees are activated.
    /// @param _token The address of target token.
    /// @param _amountOfFloat The amount of float.
    function _checkFlips(address _token, uint256 _amountOfFloat)
        internal
        view
        returns (uint8)
    {
        (uint256 reserveA, uint256 reserveB) = getFloatReserve(
            address(0),
            BTCT_ADDR
        );
        uint256 threshold = reserveA
            .add(reserveB)
            .add(_amountOfFloat)
            .mul(2)
            .div(3);
        if (_token == BTCT_ADDR && reserveB.add(_amountOfFloat) >= threshold) {
            return 1; // BTC float insufficient
        }
        if (_token == address(0) && reserveA.add(_amountOfFloat) >= threshold) {
            return 2; // BTCT float insufficient
        }
        return 0;
    }

    /// @dev _addFloat updates one side of the float.
    /// @param _token The address of target token.
    /// @param _amount The amount of float.
    function _addFloat(address _token, uint256 _amount) internal {
        floatAmountOf[_token] = floatAmountOf[_token].add(_amount);
    }

    /// @dev _removeFloat remove one side of the float - redone for skypools using tokens mapping
    /// @param _token The address of target token.
    /// @param _amount The amount of float.
    function _removeFloat(address _token, uint256 _amount) internal {
        floatAmountOf[_token] = floatAmountOf[_token].sub(
            _amount,
            "_removeFloat: float amount insufficient"
        );
    }

    /// @dev _swap collects swap amount to change float.
    /// @param _sourceToken The address of source token
    /// @param _destToken The address of target token.
    /// @param _swapAmount The amount of swap.
    function _swap(
        address _sourceToken,
        address _destToken,
        uint256 _swapAmount
    ) internal {
        floatAmountOf[_destToken] = floatAmountOf[_destToken].sub(
            _swapAmount,
            "_swap: float amount insufficient"
        );
        floatAmountOf[_sourceToken] = floatAmountOf[_sourceToken].add(
            _swapAmount
        );

        emit Swap(_sourceToken, _destToken, _swapAmount);
    }

    /// @dev _safeTransfer executes tranfer erc20 tokens
    /// @param _token The address of target token
    /// @param _to The address of receiver.
    /// @param _amount The amount of transfer.
    function _safeTransfer(
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        if (_token == BTCT_ADDR) {
            _amount = _amount.mul(convertScale);
        }
        require(IERC20(_token).transfer(_to, _amount));
    }

    /// @dev _rewardsCollection collects tx rewards.
    /// @param _feesToken The token address for collection fees.
    /// @param _rewardsAmount The amount of rewards.
    function _rewardsCollection(address _feesToken, uint256 _rewardsAmount)
        internal
    {
        if (_rewardsAmount == 0) return;
        if (_feesToken == lpToken) {
            feesLPTokensForNode = feesLPTokensForNode.add(_rewardsAmount);
            emit RewardsCollection(_feesToken, _rewardsAmount, 0, 0);
            return;
        }
        // Get current LP token price.
        uint256 nowPrice = getCurrentPriceLP();
        // Add all fees into pool
        floatAmountOf[_feesToken] = floatAmountOf[_feesToken].add(
            _rewardsAmount
        );
        uint256 amountForNodes = _rewardsAmount.mul(nodeRewardsRatio).div(100);
        // Alloc LP tokens for nodes as fees
        uint256 amountLPTokensForNode = amountForNodes.mul(lpDecimals).div(
            nowPrice
        );
        // Add minted LP tokens for Nodes
        lockedLPTokensForNode = lockedLPTokensForNode.add(
            amountLPTokensForNode
        );
        emit RewardsCollection(
            _feesToken,
            _rewardsAmount,
            amountLPTokensForNode,
            nowPrice
        );
    }

    /// @dev _addUsedTx updates txid list which is spent. (single hash)
    /// @param _txid The array of txid.
    function _addUsedTx(bytes32 _txid) internal {
        used[_txid] = true;
    }

    /// @dev _addUsedTxs updates txid list which is spent. (multiple hashes)
    /// @param _txids The array of txid.
    function _addUsedTxs(bytes32[] memory _txids) internal {
        for (uint256 i = 0; i < _txids.length; i++) {
            used[_txids[i]] = true;
        }
    }

    /// @dev _addNode updates a staker's info.
    /// @param _addr The address of staker.
    /// @param _data The data of staker.
    /// @param _remove The flag to remove node.
    function _addNode(
        address _addr,
        bytes32 _data,
        bool _remove
    ) internal returns (bool) {
        if (_remove) {
            delete nodes[_addr];
            return true;
        }
        if (!isInList[_addr]) {
            nodeAddrs.push(_addr);
            isInList[_addr] = true;
        }
        nodes[_addr] = _data;
        return true;
    }

    /// @dev _splitToValues returns address and amount of staked SWINGBYs
    /// @param _data The info of a staker.
    function _splitToValues(bytes32 _data)
        internal
        pure
        returns (address, uint256)
    {
        return (
            address(uint160(uint256(_data))),
            uint256(uint96(bytes12(_data)))
        );
    }

    /// @dev The contract doesn't allow receiving Ether.
    fallback() external {
        revert();
    }
}