// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IL1VaultConfig.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "./VaultConfigBase.sol";

contract L1VaultConfig is VaultConfigBase, IL1VaultConfig {
    string internal constant tokenName = "R-";

    /// @notice Public function to query the whitelisted tokens list
    /// @dev token address => WhitelistedToken struct
    mapping(address => WhitelistedToken) public whitelistedTokens;

    address public override wethAddress;

    struct WhitelistedToken {
        uint256 maxAssetCap;
        address underlyingReceiptAddress;
        bool allowToWithdraw;
    }

    function initialize(address _composableHolding) public initializer {
        require(
            _composableHolding != address(0),
            "Invalid ComposableHolding address"
        );
        __Ownable_init();
        composableHolding = IComposableHolding(_composableHolding);
    }

    /// @notice external function used to define a max cap per asset
    /// @param _token Token address
    /// @param _maxCap Cap
    function setMaxCapAsset(address _token, uint256 _maxCap)
        external
        override
        onlyWhitelistedToken(_token)
        validAmount(_maxCap)
        onlyOwnerOrVault(msg.sender)
    {
        require(
            getTokenBalance(_token) <= _maxCap,
            "Current token balance is higher"
        );
        whitelistedTokens[_token].maxAssetCap = _maxCap;
    }

    function setWethAddress(address _weth)
        external
        override
        onlyOwner
        validAddress(_weth)
    {
        wethAddress = _weth;
    }

    /// @notice External function used to set the underlying Receipt Address
    /// @param _token Underlying token
    /// @param _receipt Receipt token
    function setUnderlyingReceiptAddress(address _token, address _receipt)
        external
        override
        onlyOwner
        validAddress(_token)
        validAddress(_receipt)
    {
        whitelistedTokens[_token].underlyingReceiptAddress = _receipt;
    }

    function getUnderlyingReceiptAddress(address _token)
        external
        view
        override
        returns (address)
    {
        return whitelistedTokens[_token].underlyingReceiptAddress;
    }

    /// @notice external function used to add token in the whitelist
    /// @param _token ERC20 token address
    function addWhitelistedToken(address _token, uint256 _maxCap)
        external
        override
        onlyOwner
        validAddress(_token)
        validAmount(_maxCap)
    {
        whitelistedTokens[_token].maxAssetCap = _maxCap;
        _deployReceipt(_token);
    }

    /// @notice external function used to remove token from the whitelist
    /// @param _token ERC20 token address
    function removeWhitelistedToken(address _token)
        external
        override
        onlyOwner
        validAddress(_token)
    {
        delete whitelistedTokens[_token];
    }

    /// @notice External function called by the owner to pause asset withdrawal
    /// @param _token address of the ERC20 token
    function pauseWithdraw(address _token)
        external
        override
        onlyWhitelistedToken(_token)
        onlyOwner
    {
        require(whitelistedTokens[_token].allowToWithdraw, "Already paused");
        delete whitelistedTokens[_token].allowToWithdraw;
    }

    /// @notice External function called by the owner to unpause asset withdrawal
    /// @param _token address of the ERC20 token
    function unpauseWithdraw(address _token)
        external
        override
        onlyWhitelistedToken(_token)
        onlyOwner
    {
        require(!whitelistedTokens[_token].allowToWithdraw, "Already allowed");
        whitelistedTokens[_token].allowToWithdraw = true;
    }

    /// @dev Internal function called when deploy a receipt Receipt token based on already deployed ERC20 token
    function _deployReceipt(address underlyingToken) private returns (address) {
        require(
            address(receiptTokenFactory) != address(0),
            "Receipt token factory not initialized"
        );
        require(address(vault) != address(0), "Vault not initialized");

        address newReceipt = receiptTokenFactory.createReceipt(
            underlyingToken,
            tokenName,
            vault
        );
        whitelistedTokens[underlyingToken]
            .underlyingReceiptAddress = newReceipt;
        emit TokenReceiptCreated(underlyingToken);
        return newReceipt;
    }

    function isTokenWhitelisted(address _token)
        public
        view
        override
        returns (bool)
    {
        return whitelistedTokens[_token].underlyingReceiptAddress != address(0);
    }

    function allowToWithdraw(address _token)
        public
        view
        override
        returns (bool)
    {
        return whitelistedTokens[_token].allowToWithdraw;
    }

    function getMaxAssetCap(address _token)
        external
        view
        override
        returns (uint256)
    {
        return whitelistedTokens[_token].maxAssetCap;
    }

    modifier onlyOwnerOrVault(address _addr) {
        require(
            _addr == owner() || _addr == vault,
            "Only vault or owner can call this"
        );
        _;
    }

    modifier onlyWhitelistedToken(address _tokenAddress) {
        require(isTokenWhitelisted(_tokenAddress), "Token is not whitelisted");
        _;
    }
}