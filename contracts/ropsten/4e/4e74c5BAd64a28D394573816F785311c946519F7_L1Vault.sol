// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "../interfaces/IBridgeBase.sol";
import "../interfaces/IComposableHolding.sol";
import "../interfaces/ITokenFactory.sol";
import "../interfaces/IReceiptBase.sol";
import "../interfaces/IBridgeAggregator.sol";
import "../interfaces/IL1VaultConfig.sol";
import "../interfaces/IWETH.sol";

/// @title L1Vault
contract L1Vault is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IL1VaultConfig public l1VaultConfig;
    IBridgeAggregator private bridgeAggregator;

    /// @notice event emitted when a token is moved to another account
    /// @param token address of the token
    /// @param destination address of the receiver
    /// @param amount token amount sent
    event FundsMoved(
        address indexed token,
        address indexed destination,
        uint256 amount
    );

    /// @notice event emitted when a token is moved to the composable holding contract
    /// @param tokenAddress address of the token
    /// @param amount token amount sent
    event FundsDigested(
        address indexed tokenAddress,
        uint256 amount
    );

    /// @notice event emitted when user make a deposit
    /// @param sender address of the person who made the token deposit
    /// @param token address of the token
    /// @param amount amount of token deposited on this action
    /// @param totalAmount total amount of token deposited
    /// @param timestamp block.timestamp timestamp of the deposit
    event ProvideLiquidity(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 indexed totalAmount,
        uint256 timestamp
    );

    /// @notice event emitted when user withdraw token from the contract
    /// @param sender address of the person who withdraw his token
    /// @param token address of the token
    /// @param amount amount of token withdrawn
    /// @param totalAmount total amount of token remained deposited
    /// @param timestamp block.timestamp timestamp of the withdrawal
    event WithdrawLiquidity(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 indexed totalAmount,
        uint256 timestamp
    );

    function initialize(address _vaultConfig) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        l1VaultConfig = IL1VaultConfig(_vaultConfig);
    }

    /// @notice External function used by owner to set the bridge aggregator address
    /// @param _bridgeAggregator Address of the bridge aggregator
    function setBridgeAggregator(address _bridgeAggregator)
        external
        onlyOwner
        validAddress(_bridgeAggregator)
    {
        bridgeAggregator = IBridgeAggregator(_bridgeAggregator);
    }

    /// @param _token Address of the ERC20 compatible token
    function getReceiptTokenBalance(address _token)
        public
        view
        returns (uint256)
    {
        return
            IReceiptBase(l1VaultConfig.getUnderlyingReceiptAddress(_token))
                .balanceOf(msg.sender);
    }

    /// @notice External function used to move tokens to Layer2 networks
    /// @param destinationNetwork chain id of the destination network
    /// @param destination Address of the receiver on the L2 network
    /// @param token Address of the ERC20 token
    /// @param amount Amount need to be send
    /// @param _data Additional data that different bridge required in order to mint token
    function bridgeTokens(
        uint256 destinationNetwork,
        uint256 bridgeId,
        address destination,
        address token,
        uint256 amount,
        bytes calldata _data
    ) external onlyOwner validAddress(destination) validAmount(amount) {
        IComposableHolding(l1VaultConfig.getComposableHolding()).approve(
            address(bridgeAggregator),
            token,
            amount
        );
        bridgeAggregator.bridgeTokens(
            destinationNetwork,
            bridgeId,
            destination,
            token,
            amount,
            _data
        );
    }

    /// @notice External callable function used to withdraw liquidity from contract
    /// @dev This function withdraw all the liquidity provider staked
    /// @param _token address of the token
    function withdrawLiquidity(address _token) external nonReentrant {
        require(
            l1VaultConfig.allowToWithdraw(_token),
            "Withdraw paused for this token"
        );
        uint256 _providerBalance = getReceiptTokenBalance(_token);
        require(_providerBalance > 0, "Provider balance too low");
        require(
            l1VaultConfig.getTokenBalance(_token) >= _providerBalance,
            "Not enough tokens in the vault"
        );
        IReceiptBase(l1VaultConfig.getUnderlyingReceiptAddress(_token)).burn(
            msg.sender,
            _providerBalance
        );

        IComposableHolding(l1VaultConfig.getComposableHolding()).transfer(
            _token,
            msg.sender,
            _providerBalance
        );

        emit WithdrawLiquidity(
            msg.sender,
            _token,
            _providerBalance,
            0,
            block.timestamp
        );
    }

    /// @notice External callable function used to add liquidity to contract
    /// @param _token address of the deposited token
    /// @param _amount amount of token deposited
    function provideLiquidity(address _token, uint256 _amount)
        external
        whenNotPaused
        validAmount(_amount)
        onlyWhitelistedToken(_token)
        notOverMaxCap(_token, _amount)
    {
        IERC20Upgradeable(_token).safeTransferFrom(
            msg.sender,
            l1VaultConfig.getComposableHolding(),
            _amount
        );
        _provideLiquidity(_token, _amount, msg.sender);
    }

    function provideEthLiquidity()
        external
        payable
        whenNotPaused
        validAmount(msg.value)
        notOverMaxCap(l1VaultConfig.wethAddress(), msg.value)
    {
        address weth = l1VaultConfig.wethAddress();

        require(weth != address(0), "WETH not set");

        IWETH(weth).deposit{value: msg.value}();

        _provideLiquidity(weth, msg.value, msg.sender);
    }

    /// @dev Internal function that contains the deposit logic
    function _provideLiquidity(
        address _token,
        uint256 _amount,
        address _to
    ) internal returns (bool) {
        address underlyingTokenReceipt = l1VaultConfig
            .getUnderlyingReceiptAddress(_token);
        IReceiptBase(underlyingTokenReceipt).mint(msg.sender, _amount);

        emit ProvideLiquidity(
            _to,
            _token,
            _amount,
            IReceiptBase(underlyingTokenReceipt).balanceOf(msg.sender),
            block.timestamp
        );
        return true;
    }



    /**
     * @notice Used to transfer randomly sent tokens to this contract to the composable holding
     * @param _token Token's address
     */
    function digestFunds(address _token)
        external
        onlyOwner
        validAddress(_token)
    {
        uint256 balance = IERC20Upgradeable(_token).balanceOf(
            address(this)
        );
        require(balance > 0, "nothing to transfer");
        IERC20Upgradeable(_token).safeTransfer(l1VaultConfig.getComposableHolding(), balance);
        emit FundsDigested(_token, balance);
    }

    /// @notice External callable function to pause the contract
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice External callable function to unpause the contract
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }

    modifier validAmount(uint256 _value) {
        require(_value > 0, "Invalid amount");
        _;
    }

    modifier onlyWhitelistedToken(address _tokenAddress) {
        require(
            l1VaultConfig.isTokenWhitelisted(_tokenAddress),
            "Token is not whitelisted"
        );
        _;
    }

    modifier notOverMaxCap(address _token, uint256 _amount) {
        uint256 _tokenBalance = l1VaultConfig.getTokenBalance(_token);
        require(
            _tokenBalance.add(_amount) <= l1VaultConfig.getMaxAssetCap(_token),
            "Amount exceed max cap per asset"
        );
        _;
    }
}