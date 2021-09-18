// SPDX-License-Identifier: MIT
// @unsupported: ovm
pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/IL1VaultConfig.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "./VaultConfigBase.sol";

contract L1VaultConfig is VaultConfigBase, IL1VaultConfig {
    string internal constant override tokenName = "R-";

    /// @notice Public function to query the supported wallets
    /// @dev wallet address => bool supported/not supported
    mapping(address => bool) public override whitelistedWallets;

    /// @notice Public function to query the supported tokens list
    /// @dev token address => WhitelistedToken struct
    mapping(address => WhitelistedToken) public whitelistedTokens;

    struct WhitelistedToken
    {
        uint256 maxAssetCap;
        address underlyingReceiptAddress;
        bool allowToWithdraw;
    }

    /// @notice event emitted when a new wallet is added to the whitelist
    /// @param wallet address of the wallet
    event WalletAddedToWhitelist(address indexed wallet);

    /// @notice event emitted when a wallet is removed from the whitelist
    /// @param wallet address of the wallet
    event WalletRemovedFromWhitelist(address indexed wallet);

    constructor(address _composableHolding) public {
        require(
            _composableHolding != address(0),
            "Invalid ComposableHolding address"
        );
        composableHolding = IComposableHolding(_composableHolding);
    }

    /// @notice external function used to define a max cap per asset
    /// @param _token Token address
    /// @param _maxCap Cap
    function setMaxCapAsset(address _token, uint256 _maxCap)
    external
    override
    onlySupportedToken(_token)
    validAmount(_maxCap)
    onlyOwnerOrVault(msg.sender)
    {
        require(getTokenBalance(_token) <= _maxCap, "Current token balance is higher");
        whitelistedTokens[_token].maxAssetCap = _maxCap;
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
    override
    view
    returns(address)
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

    /// @notice external function used to add wallet in the whitelist
    /// @param _wallet Wallet address
    function addWhitelistedWallet(address _wallet)
    external
    onlyOwner
    validAddress(_wallet)
    {
        whitelistedWallets[_wallet] = true;

        emit WalletAddedToWhitelist(_wallet);
    }

    /// @notice external function used to remove wallet from the whitelist
    /// @param _wallet Wallet address
    function removeWhitelistedWallet(address _wallet)
    external
    onlyOwner
    validAddress(_wallet)
    {
        require(whitelistedWallets[_wallet] == true, "Not registered");
        delete whitelistedWallets[_wallet];

        emit WalletRemovedFromWhitelist(_wallet);
    }

    /// @notice External function called by the owner to pause asset withdrawal
    /// @param _token address of the ERC20 token
    function pauseWithdraw(address _token)
    external
    override
    onlySupportedToken(_token)
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
    onlySupportedToken(_token)
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
        whitelistedTokens[underlyingToken].underlyingReceiptAddress = newReceipt;
        emit TokenReceiptCreated(underlyingToken);
        return newReceipt;
    }

    function isTokenSupported(address _token) public override view returns(bool) {
        return whitelistedTokens[_token].underlyingReceiptAddress != address(0);
    }

    function allowToWithdraw(address _token) public override view returns(bool) {
        return whitelistedTokens[_token].allowToWithdraw;
    }

    function getMaxAssetCap(address _token) external override view returns(uint) {
        return whitelistedTokens[_token].maxAssetCap;
    }

    modifier onlyOwnerOrVault(address _addr) {
        require(
            _addr == owner() || _addr == vault,
            "Only vault or owner can call this"
        );
        _;
    }

    modifier onlySupportedToken(address _tokenAddress) {
        require(isTokenSupported(_tokenAddress), "Token is not supported");
        _;
    }
}