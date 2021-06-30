// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./lib/AssetLib.sol";

import "./interfaces/IAssetDeployCode.sol";
import "./interfaces/IAsset.sol";
import "./interfaces/IStaking.sol";

contract AssetFactory is AccessControl, ReentrancyGuard {
    // public
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    address public deployCodeContract;
    address public oracle;
    address public dexRouter;
    address public dexFactory;
    address public weth;
    address public zVault;

    address[] public allAssets;

    mapping(address => bool) public isTokenDefaultWhitelisted;
    address[] public defaultTokenWhitelist;

    // private
    mapping(address => uint256) private _defaultWhitelistIndexes;

    event NewAssetDeploy(
        address newAsset,
        string name,
        string symbol,
        uint256 imeStartTimestamp,
        uint256 imeEndTimestamp,
        address[] tokensInAsset,
        uint256[] tokensDistribution
    );

    modifier onlyManagerOrAdmin {
        address sender = _msgSender();
        require(
            hasRole(MANAGER_ROLE, sender) || hasRole(DEFAULT_ADMIN_ROLE, sender),
            "Access error"
        );
        _;
    }

    constructor(address _deployCodeContract, address _dexRouter, address _dexFactory) {
        deployCodeContract = _deployCodeContract;
        dexRouter = _dexRouter;
        dexFactory = _dexFactory;
        weth = IPancakeRouter02(_dexRouter).WETH();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
    }

    function deployNewAsset(
        string memory name,
        string memory symbol,
        uint256[2] memory imeTimeParameters,
        address[] memory tokensInAsset,
        uint256[] memory tokensDistribution
    ) external virtual onlyManagerOrAdmin returns (address) {
        address _zVault = zVault;
        require(oracle != address(0), "Oracle not found");
        require(_zVault != address(0), "Oracle not found");

        IAsset assetInst = _deployAsset(
            name,
            symbol,
            imeTimeParameters,
            tokensInAsset,
            tokensDistribution
        );

        IStaking(_zVault).createPool(address(assetInst));

        emit NewAssetDeploy(
            address(assetInst),
            name,
            symbol,
            imeTimeParameters[0],
            imeTimeParameters[1],
            tokensInAsset,
            tokensDistribution
        );

        return address(assetInst);
    }

    function changeIsTokenWhitelisted(address token, bool value)
        external
        onlyManagerOrAdmin
        nonReentrant
    {
        AssetLib.changeWhitelist(
            token,
            value,
            [dexFactory, weth],
            defaultTokenWhitelist,
            isTokenDefaultWhitelisted,
            _defaultWhitelistIndexes
        );
    }

    function changeOracle(address newOracle) external onlyManagerOrAdmin {
        require(oracle == address(0) && newOracle != address(0), "Bad use");
        oracle = newOracle;
    }

    function changeZVault(address newZVault) external onlyManagerOrAdmin {
        require(zVault == address(0) && newZVault != address(0), "Bad use");
        zVault = newZVault;
    }

    function allAssetsLen() external view returns (uint256) {
        return allAssets.length;
    }

    function defaultTokenWhitelistLen() external view returns(uint256) {
        return defaultTokenWhitelist.length;
    }

    function _deployAsset(
        string memory name,
        string memory symbol,
        uint256[2] memory imeTimeParameters,
        address[] memory tokensInAsset,
        uint256[] memory tokensDistribution
    ) internal returns(IAsset assetInst) {
        (bool success, bytes memory data) =
            deployCodeContract.delegatecall(
                abi.encodeWithSelector(
                    IAssetDeployCode.newAsset.selector,
                    bytes32(allAssets.length)
                )
            );
        require(success == true, "Deploy failed");

        assetInst = IAsset(abi.decode(data, (address)));
        assetInst.__Asset_init(
            [name, symbol],
            [oracle, dexRouter, dexFactory, zVault],
            imeTimeParameters,
            defaultTokenWhitelist,
            tokensInAsset,
            tokensDistribution
        );

        allAssets.push(address(assetInst));
    }
}