// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDOPool.sol";
import "./CoinXPadInvestmentsInfo.sol";

/// @title CoinXPadPoolFactory
/// @notice Factory contract to create PreSale
contract CoinXPadPoolFactory is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @dev Struct to store the IDO Pool Information
     * @param contractAddr The contract address
     * @param currency The curreny used for the IDO
     * @param token The ERC20 token contract address
     */
    struct IDOPoolInfo {
        address contractAddr;
        address currency;
        address token;
    }

    /**
     * @dev Struct to store IDO Information
     * @param _token The ERC20 token contract address
     * @param _currency The curreny used for the IDO
     * @param _startTime Timestamp of when sale starts
     * @param _endTime Timestamp of when sale ends
     * @param _releaseTime Timestamp of when the token will be released
     * @param _fcfsStartTime Timestamp of when the token will be released for FCFS allocation
     * @param _price Price of the token for the IDO
     * @param _totalAmount The total amount for the IDO
     * @param _maxAmountThatCanBeInvestedInFCFS Max amount that can be invested in FCFS
     * @param _minAmountThatCanBeInvestedInFCFS Min amount that can be invested in FCFS
     * @param _balanceRequiredForInvestmentInFCFS Balance required for investment in FCFS
     * @param _fcfsAllocation Tokens allocated for FCFS
     * @param _maxAmountThatCanBeInvestedInTiers An array of max investments amount in tiers
     * @param _minAmountThatCanBeInvestedInTiers An array of min investments amount in tiers
     * @param _noOfWhiteListAddressesAsPerTiers An array indicating number of white list addresses as per tiers
     * @param _presaleProjectID The PreSale project ID
     * @param _whitelistedAddresses An array of whitelist addresses for all tiers
     * @param _tiersAllocation An array of amounts as per tiers
     * @param _tiersDuration An array of timestamps indication of duration of each tier
     * @param _canBuyAfterMinutes An array of minutes indication of after how many minutes of
       startTime buy can be executed
     */
    struct IDOInfo {
        address _token;
        address _currency;
        uint256 _startTime;
        uint256 _endTime;
        uint256 _releaseTime;
        uint256 _fcfsStartTime;
        uint256 _fcfsEndTime;
        uint256 _price;
        uint256 _totalAmount;
        uint256 _presaleProjectID;
        uint256 _maxAmountThatCanBeInvestedInFCFS;
        uint256 _minAmountThatCanBeInvestedInFCFS;
        uint256 _balanceRequiredForInvestmentInFCFS;
        uint256 _fcfsAllocation;
        uint256[] _maxAmountThatCanBeInvestedInTiers;
        uint256[] _minAmountThatCanBeInvestedInTiers;
        uint256[] _noOfWhiteListAddressesAsPerTiers;
        address[] _whitelistedAddresses;
        uint256[] _tiersAllocation;
    }

    uint256 public nextPoolId;
    IDOPoolInfo[] public poolList;

    //solhint-disable-next-line var-name-mixedcase
    CoinXPadInvestmentsInfo public immutable coinXPadInfo;

    IERC20 public platformToken; // Platform token

    event PoolCreated(
        uint256 indexed coinXPadId,
        uint256 presaleDbID,
        address indexed _token,
        address indexed _currency,
        address pool,
        address creator
    );

    /**
     * @dev Sets the values for {_coinxpadInfoAddress, _platformToken}
     *
     * All two of these values are immutable: they can only be set once during construction.
     */
    constructor(address _coinxpadInfoAddress, address _platformToken) {
        coinXPadInfo = CoinXPadInvestmentsInfo(_coinxpadInfoAddress);
        platformToken = IERC20(_platformToken);
    }

    /**
     * @dev To create a pool
     *
     * Requirements:
     * - poolinfo token & currency cannot be the same
     * - poolinfo token cannot be address zero
     * - poolinfo currency cannot be address zero
     */
    //solhint-disable-next-line function-max-lines
    function createPoolPublic(IDOInfo calldata poolInfo) external onlyOwner returns (uint256, address) {
        require(poolInfo._token != poolInfo._currency, "Currency and Token can not be the same");
        require(poolInfo._token != address(0), "PoolInfo token cannot be address zero");
        require(poolInfo._currency != address(0), "PoolInfo currency cannot be address zero");
        uint256 sumOfAmtOfAllTiersAndFCFS = 0;
        uint256 tiersAllocLength = poolInfo._tiersAllocation.length;
        for (uint256 i = 0; i < tiersAllocLength; i++) {
            sumOfAmtOfAllTiersAndFCFS = sumOfAmtOfAllTiersAndFCFS.add(poolInfo._tiersAllocation[i]);
        }
        sumOfAmtOfAllTiersAndFCFS = sumOfAmtOfAllTiersAndFCFS.add(poolInfo._fcfsAllocation);
        require(
            poolInfo._totalAmount == sumOfAmtOfAllTiersAndFCFS,
            "PoolInfo totalAmount & sumOfAmtOfAllTiersAndFCFS are unequal"
        );

        IERC20 tokenIDO = IERC20(poolInfo._token);

        IDOPool _idoPool = new IDOPool(
            poolInfo._token,
            poolInfo._currency,
            poolInfo._startTime,
            poolInfo._endTime,
            poolInfo._releaseTime,
            poolInfo._price,
            poolInfo._totalAmount
        );

        tokenIDO.transferFrom(msg.sender, address(_idoPool), poolInfo._totalAmount);

        poolList.push(IDOPoolInfo(address(_idoPool), poolInfo._currency, poolInfo._token));

        uint256 coinXPadId = coinXPadInfo.addPresaleAddress(address(_idoPool), poolInfo._presaleProjectID);

        _idoPool.setPlatformTokenAddress(address(platformToken));

        uint256 k = 0;
        uint256 j = 0;
        for (uint256 i = 0; i < poolInfo._noOfWhiteListAddressesAsPerTiers.length; i++) {
            address[] memory whiteListAddresses = new address[](poolInfo._noOfWhiteListAddressesAsPerTiers[i]);
            for (j = 0; j < poolInfo._noOfWhiteListAddressesAsPerTiers[i]; j++) {
                whiteListAddresses[j] = poolInfo._whitelistedAddresses[i + j + k];
            }
            initializeWhitelistedAddresses(_idoPool, whiteListAddresses, uint8(i + 1));
            k = j - 1;
        }

        setIDOTierInfo(
            _idoPool,
            poolInfo._tiersAllocation,
            poolInfo._maxAmountThatCanBeInvestedInTiers,
            poolInfo._minAmountThatCanBeInvestedInTiers
        );

        _idoPool.setFCFSTime(
            poolInfo._fcfsStartTime,
            poolInfo._fcfsEndTime
        );

        _idoPool.setFCFSAllocInfo(
            poolInfo._maxAmountThatCanBeInvestedInFCFS,
            poolInfo. _minAmountThatCanBeInvestedInFCFS,
            poolInfo._balanceRequiredForInvestmentInFCFS,
            poolInfo._fcfsAllocation
        );

        _idoPool.transferOwnership(owner());

        emit PoolCreated(
            coinXPadId,
            poolInfo._presaleProjectID,
            poolInfo._token,
            poolInfo._currency,
            address(_idoPool),
            msg.sender
        );

         return (coinXPadId, address(_idoPool));
    }

    /**
     * @dev To set tier information in IDO contract
     * @param _pool The IDOPool contract object
     * @param _tiersAllocation An array of tiers allocation
     */
    function setIDOTierInfo(
        IDOPool _pool,
        uint256[] calldata _tiersAllocation,
        uint256[] calldata _maxAmountThatCanBeInvestedInTiers,
        uint256[] calldata _minAmountThatCanBeInvestedInTiers
    ) internal {
        _pool.setTierInfo(
            _tiersAllocation,
            _maxAmountThatCanBeInvestedInTiers,
            _minAmountThatCanBeInvestedInTiers
        );
    }

    /**
     * @dev To initialize whitelsited addresses
     * @param _pool The IDOPool contract object
     * @param _whitelistedAddresses An array of addresses
     * @param _tier Tier to which the addresses belong
     */
    function initializeWhitelistedAddresses(
        IDOPool _pool,
        address[] memory _whitelistedAddresses,
        uint8 _tier
    ) internal {
        _pool.addToPoolWhiteList(_whitelistedAddresses, _tier);
    }
}