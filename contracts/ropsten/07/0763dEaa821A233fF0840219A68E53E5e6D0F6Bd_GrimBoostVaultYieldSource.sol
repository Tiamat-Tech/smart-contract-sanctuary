// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import "./interfaces/IYieldSource.sol";
import "./external/grim/GrimBoostVaultInterface.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

/// @title Yield source for a PoolTogether prize pool that generates yield by depositing into Yearn Vaults.
/// @dev This contract inherits from the ERC20 implementation to keep track of users deposits
/// @dev This is a generic contract that will work with main Yearn Vaults. Vaults using v0.3.2 to v0.3.4 included
/// @dev are not compatible, as they had dips in shareValue due to a small miscalculation
/// @notice Yield Source Prize Pools subclasses need to implement this interface so that yield can be generated.
contract GrimBoostVaultYieldSource is
    IYieldSource,
    ERC20Upgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /// @notice Yearn Vault which manages `token` to generate yield
    GrimBoostVaultInterface public vault;
    /// @dev Deposit Token contract address
    IERC20Upgradeable internal token;

    /// @notice Emitted when asset tokens are supplied to sponsor the yield source
    event Sponsored(address indexed user, uint256 amount);

    /// @notice Emitted when the yield source is initialized
    event YieldSourceGrimBoostVaultInitialized(
        GrimBoostVaultInterface vault,
        IERC20Upgradeable token
    );

    /// @notice Emitted when asset tokens are supplied to the yield source
    event SuppliedTokenTo(
        address indexed from,
        uint256 shares,
        uint256 amount,
        address indexed to
    );

    /// @notice Emitted when asset tokens are redeemed from the yield source
    event RedeemedToken(address indexed from, uint256 shares, uint256 amount);

    /// @notice Initializes the yield source with
    /// @param _vault GrimBoostVault Vault in which the Yield Source will deposit `token` to generate Yield
    /// @param _token Underlying Token / Deposit Token
    function initialize(
        GrimBoostVaultInterface _vault,
        IERC20Upgradeable _token
    ) public initializer {
        require(address(vault) == address(0), "!already initialized");
        vault = _vault;
        token = _token;

        __Ownable_init();

        _token.safeApprove(address(vault), type(uint256).max);

        emit YieldSourceGrimBoostVaultInitialized(_vault, _token);
    }

    /// @notice Returns the ERC20 asset token used for deposits
    /// @return The ERC20 asset token address
    function depositToken() external view override returns (address) {
        return address(token);
    }

    /// @notice Returns user total balance (in asset tokens). This includes the deposits and interest.
    /// @param addr User address
    /// @return The underlying balance of asset tokens
    function balanceOfToken(address addr) external override returns (uint256) {
        return _sharesToToken(balanceOf(addr));
    }

    /// @notice Supplies asset tokens to the yield source
    /// @dev Shares corresponding to the number of tokens supplied are mint to the user's balance
    /// @dev Asset tokens are supplied to the yield source, then deposited into Grim
    /// @param _amount The amount of asset tokens to be supplied
    /// @param to The user whose balance will receive the tokens
    function supplyTokenTo(uint256 _amount, address to) external override {
        uint256 shares = _tokenToShares(_amount);

        _mint(to, shares);

        // NOTE: we have to deposit after calculating shares to mint
        token.safeTransferFrom(msg.sender, address(this), _amount);

        _depositInVault();

        emit SuppliedTokenTo(msg.sender, shares, _amount, to);
    }

    /// @notice Redeems asset tokens from the yield source
    /// @dev Shares corresponding to the number of tokens withdrawn are burnt from the user's balance
    /// @dev Asset tokens are withdrawn from Yearn's Vault, then transferred from the yield source to the user's wallet
    /// @param amount The amount of asset tokens to be redeemed
    /// @return The actual amount of tokens that were redeemed
    function redeemToken(uint256 amount) external override returns (uint256) {
        uint256 shares = _tokenToShares(amount);

        uint256 withdrawnAmount = _withdrawFromVault(amount);

        _burn(msg.sender, shares);

        token.safeTransfer(msg.sender, withdrawnAmount);

        emit RedeemedToken(msg.sender, shares, amount);
        return withdrawnAmount;
    }

    /// @notice Allows someone to deposit into the yield source without receiving any shares
    /// @dev This allows anyone to distribute tokens among the share holders
    /// @param amount The amount of tokens to deposit
    function sponsor(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);

        _depositInVault();

        emit Sponsored(msg.sender, amount);
    }

    // ************************ INTERNAL FUNCTIONS ************************

    /// @notice Deposits full balance (or max available deposit) into Yearn's Vault
    /// @dev if deposit limit is reached, tokens will remain in the Yield Source and
    /// @dev they will be queued for retries in subsequent deposits
    function _depositInVault() internal {
        GrimBoostVaultInterface v = vault; // NOTE: for gas usage
        if (
            token.allowance(address(this), address(v)) <
            token.balanceOf(address(this))
        ) {
            token.safeApprove(address(v), 0);
            token.safeApprove(address(v), type(uint256).max);
        }
        // this will deposit full balance (for cases like not enough room in Vault)
        v.depositAll();
    }

    /// @notice Withdraws requested amount from Vault
    /// @dev Vault withdrawal function required amount of shares to be redeemed
    /// @dev Losses are accepted by the Yield Source to avoid funds being locked in the Vault if something happened
    /// @param amount amount of asset tokens to be redeemed
    /// @return Tokens received from the Vault
    function _withdrawFromVault(uint256 amount) internal returns (uint256) {
        uint256 gShares = _tokenToGShares(amount);
        uint256 previousBalance = token.balanceOf(address(this));
        vault.withdraw(gShares);
        uint256 currentBalance = token.balanceOf(address(this));

        return previousBalance.sub(currentBalance);
    }

    /// @notice Returns the amount of shares of yearn's vault that the Yield Source holds
    /// @return Balance of vault's shares holded by Yield Source
    function _balanceOfYShares() internal view returns (uint256) {
        return vault.balanceOf(address(this));
    }

    /// @notice Ratio between gShares and underlying token
    /// @dev use this to convert from shares to deposit tokens and viceversa
    /// @dev (see _tokenToGShares & _ySharesToToken)
    /// @return Price per vault's share
    function _pricePerYShare() internal view returns (uint256) {
        return vault.getPricePerFullShare();
    }

    /// @notice Balance of deposit token held in the Yield Source
    /// @return balance of deposit token
    function _balanceOfToken() internal view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Total Assets under Management by Yield Source, denominated in Deposit Token
    /// @dev amount of deposit token held in Yield Source + investment (amount held in Yearn's Vault)
    /// @return Total AUM denominated in deposit Token
    function _totalAssetsInToken() internal view returns (uint256) {
        return _balanceOfToken().add(_ySharesToToken(_balanceOfYShares()));
    }

    /// @notice Support function to retrieve used by Vault
    /// @dev used to correctly scale prices
    /// @return decimals of vault's shares (and underlying token)
    function _vaultDecimals() internal view returns (uint256) {
        return vault.decimals();
    }

    // ************************ CALCS ************************

    /// @notice Converter from deposit token to gShares (yearn vault's shares)
    /// @param tokens Amount of tokens to be converted
    /// @return gShares to redeem to receive `tokens` deposit token
    function _tokenToGShares(uint256 tokens) internal view returns (uint256) {
        return tokens.mul(10**_vaultDecimals()).div(_pricePerYShare());
    }

    /// @notice Converter from deposit gShares (yearn vault's shares) to token
    /// @param gShares Vault's shares to be converted
    /// @return tokens that will be received if gShares shares are redeemed
    function _ySharesToToken(uint256 gShares) internal view returns (uint256) {
        return gShares.mul(_pricePerYShare()).div(10**_vaultDecimals());
    }

    /// @notice Function to calculate the amount of Yield Source shares equivalent to a deposit tokens amount
    /// @param tokens amount of tokens to be converted
    /// @return shares number of shares equivalent to the amount of tokens
    function _tokenToShares(uint256 tokens)
        internal
        view
        returns (uint256 shares)
    {
        if (totalSupply() == 0) {
            shares = tokens;
        } else {
            uint256 _totalTokens = _totalAssetsInToken();
            shares = tokens.mul(totalSupply()).div(_totalTokens);
        }
    }

    /// @notice Function to calculate the amount of Deposit Tokens equivalent to a Yield Source shares amount
    /// @param shares amount of Yield Source shares to be converted
    /// @dev used to calculate how many shares to mint / burn when depositing / withdrawing
    /// @return tokens number of tokens equivalent (in value) to the amount of Yield Source shares
    function _sharesToToken(uint256 shares)
        internal
        view
        returns (uint256 tokens)
    {
        if (totalSupply() == 0) {
            tokens = shares;
        } else {
            uint256 _totalTokens = _totalAssetsInToken();
            tokens = shares.mul(_totalTokens).div(totalSupply());
        }
    }

    /// @notice Pure support function to compare strings
    /// @param a One string
    /// @param b Another string
    /// @return Whether or not the strings are the same or not
    function areEqualStrings(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
}