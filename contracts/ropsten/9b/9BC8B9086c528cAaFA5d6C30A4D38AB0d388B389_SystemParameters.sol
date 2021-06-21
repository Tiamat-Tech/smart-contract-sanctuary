// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAssetParameters.sol";

import "./LiquidityPoolFactory.sol";
import "./LiquidityPool.sol";
import "./common/PureParameters.sol";
import "./PriceOracle.sol";

contract AssetParameters is Ownable, IAssetParameters {
    using PureParameters for PureParameters.Param;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    IPriceOracle private priceOracle;

    Registry private _registry;
    EnumerableSet.Bytes32Set private _supportedAssets;

    bytes32 public constant FREEZE_KEY = keccak256("FREEZE_KEY");
    bytes32 public constant ENABLE_COLLATERAL_KEY = keccak256("ENABLE_COLLATERAL_KEY");

    bytes32 public constant BASE_PERCENTAGE_KEY = keccak256("BASE_PERCENTAGE_KEY");
    bytes32 public constant FIRST_SLOPE_KEY = keccak256("FIRST_SLOPE_KEY");
    bytes32 public constant SECOND_SLOPE_KEY = keccak256("SECOND_SLOPE_KEY");
    bytes32 public constant UTILIZATION_BREAKING_POINT_KEY =
        keccak256("UTILIZATION_BREAKING_POINT_KEY");
    bytes32 public constant MAX_UTILIZATION_RATIO_KEY = keccak256("MAX_UTILIZATION_RATIO_KEY");

    struct InterestRateParams {
        uint256 basePercentage;
        uint256 firstSlope;
        uint256 secondSlope;
        uint256 utilizationBreakingPoint;
    }

    mapping(bytes32 => mapping(bytes32 => PureParameters.Param)) private _parameters;

    mapping(bytes32 => address) public availableAssets;
    mapping(bytes32 => address) public liquidityPools;

    modifier onlyExist(bytes32 _assetKey) {
        require(onlyExistingAsset(_assetKey), "AssetParameters: Asset doesn't exist.");
        _;
    }

    constructor(address _registryAddr, address _priceOracle) Ownable() {
        _registry = Registry(_registryAddr);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function getSupportedAssets() external view returns (bytes32[] memory _resultArr) {
        uint256 _assetsCount = _supportedAssets.length();

        _resultArr = new bytes32[](_assetsCount);

        for (uint256 i = 0; i < _assetsCount; i++) {
            _resultArr[i] = _supportedAssets.at(i);
        }
    }

    function addUintParam(
        bytes32 _assetKey,
        bytes32 _paramKey,
        uint256 _value
    ) external onlyOwner onlyExist(_assetKey) {
        _addParam(_assetKey, _paramKey, PureParameters.makeUintParam(_value));
    }

    function addBytes32Param(
        bytes32 _assetKey,
        bytes32 _paramKey,
        bytes32 _value
    ) external onlyOwner onlyExist(_assetKey) {
        _addParam(_assetKey, _paramKey, PureParameters.makeBytes32Param(_value));
    }

    function addAddrParam(
        bytes32 _assetKey,
        bytes32 _paramKey,
        address _value
    ) external onlyOwner onlyExist(_assetKey) {
        _addParam(_assetKey, _paramKey, PureParameters.makeAdrressParam(_value));
    }

    function addBoolParam(
        bytes32 _assetKey,
        bytes32 _paramKey,
        bool _value
    ) external onlyOwner onlyExist(_assetKey) {
        require(
            _paramKey != ENABLE_COLLATERAL_KEY,
            "AssetParameters: Changing param in this way is not available."
        );
        _addParam(_assetKey, _paramKey, PureParameters.makeBoolParam(_value));
    }

    function _addParam(
        bytes32 _assetKey,
        bytes32 _paramKey,
        PureParameters.Param memory _param
    ) internal {
        _parameters[_assetKey][_paramKey] = _param;

        emit ParamAdded(_assetKey, _paramKey);
    }

    function getUintParam(bytes32 _assetKey, bytes32 _paramKey)
        external
        view
        override
        onlyExist(_assetKey)
        returns (uint256)
    {
        return _getParam(_assetKey, _paramKey).getUintFromParam();
    }

    function getBytes32Param(bytes32 _assetKey, bytes32 _paramKey)
        external
        view
        override
        onlyExist(_assetKey)
        returns (bytes32)
    {
        return _getParam(_assetKey, _paramKey).getBytes32FromParam();
    }

    function getAddressParam(bytes32 _assetKey, bytes32 _paramKey)
        external
        view
        override
        onlyExist(_assetKey)
        returns (address)
    {
        return _getParam(_assetKey, _paramKey).getAdrressFromParam();
    }

    function getBoolParam(bytes32 _assetKey, bytes32 _paramKey)
        external
        view
        override
        onlyExist(_assetKey)
        returns (bool)
    {
        return _getParam(_assetKey, _paramKey).getBoolFromParam();
    }

    function _getParam(bytes32 _assetKey, bytes32 _paramKey)
        internal
        view
        returns (PureParameters.Param memory)
    {
        require(
            PureParameters.paramExists(_parameters[_assetKey][_paramKey]),
            "AssetParameters: Param for this asset doesn't exist."
        );

        return _parameters[_assetKey][_paramKey];
    }

    function removeParam(bytes32 _assetKey, bytes32 _paramKey)
        external
        onlyOwner
        onlyExist(_assetKey)
    {
        require(
            PureParameters.paramExists(_parameters[_assetKey][_paramKey]),
            "AssetParameters: Param for this asset doesn't exist."
        );

        delete _parameters[_assetKey][_paramKey];

        emit ParamRemoved(_assetKey, _paramKey);
    }

    function setupInterestRateModel(
        bytes32 _assetKey,
        uint256 _basePercentage,
        uint256 _firstSlope,
        uint256 _secondSlope,
        uint256 _utilizationBreakingPoint,
        uint256 _maxUtilizationRatio
    ) external onlyOwner onlyExist(_assetKey) {
        require(_basePercentage <= ONE_PERCENT * 3, "AssetParameters: Invalid base percentage.");
        require(
            _firstSlope >= ONE_PERCENT * 3 && _firstSlope <= ONE_PERCENT * 10,
            "AssetParameters: Invalid first slope percentage."
        );
        require(
            _secondSlope >= ONE_PERCENT * 50 && _secondSlope <= DECIMAL,
            "AssetParameters: Invalid second slope percentage."
        );
        require(
            _utilizationBreakingPoint >= ONE_PERCENT * 60 &&
                _utilizationBreakingPoint <= ONE_PERCENT * 85,
            "AssetParameters: Invalid utilization breaking point percentage."
        );
        require(
            _maxUtilizationRatio >= ONE_PERCENT * 90 && _maxUtilizationRatio < DECIMAL,
            "AssetParameters: Invalid max utilization ratio percentage."
        );

        _addParam(_assetKey, BASE_PERCENTAGE_KEY, PureParameters.makeUintParam(_basePercentage));
        _addParam(_assetKey, FIRST_SLOPE_KEY, PureParameters.makeUintParam(_firstSlope));
        _addParam(_assetKey, SECOND_SLOPE_KEY, PureParameters.makeUintParam(_secondSlope));
        _addParam(
            _assetKey,
            UTILIZATION_BREAKING_POINT_KEY,
            PureParameters.makeUintParam(_utilizationBreakingPoint)
        );
        _addParam(
            _assetKey,
            MAX_UTILIZATION_RATIO_KEY,
            PureParameters.makeUintParam(_maxUtilizationRatio)
        );
    }

    function getInterestRateParams(bytes32 _assetKey)
        external
        view
        onlyExist(_assetKey)
        returns (InterestRateParams memory _params)
    {
        _params.basePercentage = PureParameters.getUintFromParam(
            _getParam(_assetKey, BASE_PERCENTAGE_KEY)
        );
        _params.firstSlope = PureParameters.getUintFromParam(
            _getParam(_assetKey, FIRST_SLOPE_KEY)
        );
        _params.secondSlope = PureParameters.getUintFromParam(
            _getParam(_assetKey, SECOND_SLOPE_KEY)
        );
        _params.utilizationBreakingPoint = PureParameters.getUintFromParam(
            _getParam(_assetKey, UTILIZATION_BREAKING_POINT_KEY)
        );
    }

    function freeze(bytes32 _assetKey) external onlyOwner onlyExist(_assetKey) {
        _addParam(_assetKey, FREEZE_KEY, PureParameters.makeBoolParam(true));

        emit Freezed(_assetKey);
    }

    function enableCollateral(bytes32 _assetKey) external onlyOwner {
        _addParam(_assetKey, ENABLE_COLLATERAL_KEY, PureParameters.makeBoolParam(true));
    }

    function addLiquidityPool(
        address _assetAddr,
        bytes32 _assetKey,
        string memory _tokenSymbol,
        bool _isCollateral
    ) external onlyOwner {
        require(_assetKey > 0, "AssetParameters: Unable to add an asset without a key.");
        require(
            _assetAddr != address(0),
            "AssetParameters: Unable to add an asset with a zero address."
        );
        require(
            !onlyExistingAsset(_assetKey),
            "AssetParameters: Liquidity pool with such a key already exists."
        );

        address _poolAddr =
            LiquidityPoolFactory(_registry.getLiquidityPoolFactoryContract()).newLiquidityPool(
                _assetAddr,
                _assetKey,
                _tokenSymbol
            );

        liquidityPools[_assetKey] = _poolAddr;
        availableAssets[_assetKey] = _assetAddr;

        _supportedAssets.add(_assetKey);
        _addParam(_assetKey, FREEZE_KEY, PureParameters.makeBoolParam(false));

        _addParam(_assetKey, ENABLE_COLLATERAL_KEY, PureParameters.makeBoolParam(_isCollateral));

        emit PoolAdded(_assetKey, _assetAddr, _poolAddr);
    }

    function withdrawAllReservedFunds(address _recipientAddr) external onlyOwner {
        uint256 _assetsCount = _supportedAssets.length();

        for (uint256 i = 0; i < _assetsCount; i++) {
            LiquidityPool(liquidityPools[_supportedAssets.at(i)]).withdrawReservedFunds(
                _recipientAddr,
                0,
                true
            );
        }
    }

    function withdrawReservedFunds(
        address _recipientAddr,
        bytes32 _assetKey,
        uint256 _amountToWithdraw
    ) external onlyOwner {
        require(onlyExistingAsset(_assetKey), "AssetParameters: Asset doesn't exist.");

        LiquidityPool(liquidityPools[_assetKey]).withdrawReservedFunds(
            _recipientAddr,
            _amountToWithdraw,
            false
        );
    }

    function onlyExistingAsset(bytes32 _assetKey) public view returns (bool) {
        return availableAssets[_assetKey] != address(0);
    }

    function getAssetPrice(bytes32 _assetKey) external view returns (uint256) {
        return priceOracle.getAssetPrice(_assetKey);
    }
}