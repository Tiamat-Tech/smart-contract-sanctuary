// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";


/**
 * New strategy contract must utilize ERC20 and with functions below:
 *
 * In constructor, _setupDecimals(decimals) follow token decimals
 * 
 * function deposit(uint256[] memory _amounts)
 * -> Receive list as argument
 * -> require msg.sender == Vault
 * 
 * function withdraw(uint256[] memory _shares)
 * -> Receive list as argument
 * -> require msg.sender == Vault
 * 
 * function refund(uint256 _shares)
 * -> Receive amount of shares (same amount with daoToken) as argument
 * -> require msg.sender == Vault
 * 
 * function approveMigrate()
 * -> Approve Vault to migrate all funds to new strategy
 */
import "../../interfaces/IStrategyUpgradeable.sol";

/// @title Contract to interact between user and strategy, and distribute daoToken to user
contract DAOVaultMediumUSDT is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    bool private initialized;

    IERC20Upgradeable public token;
    IStrategyUpgradeable public strategy;
    address public pendingStrategy;

    bool public canSetPendingStrategy;
    uint256 public unlockTime;
    uint256 public constant LOCKTIME = 2 days;

    event MigrateFunds(address indexed fromStrategy, address indexed toStrategy, uint256 amount);

    function initialize(address _token, address _strategy) initializer public {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;

        __Ownable_init();
        __ERC20_init("DAO Vault Medium USDT", "dvmUSDT");

        _setupDecimals(6);

        token = IERC20Upgradeable(_token);
        strategy = IStrategyUpgradeable(_strategy);

        canSetPendingStrategy = true;
    }

    /**
     * @notice Deposit into strategy
     * @param _amounts A list that contains amounts to deposit
     * Requirements:
     * - Only EOA account can call this function
     */
    function deposit(uint256[] memory _amounts) external {
        require(!address(msg.sender).isContract(), "Only EOA");

        uint256 _before = strategy.balanceOf(address(this));
        strategy.deposit(_amounts);
        uint256 _after = strategy.balanceOf(address(this));
        
        _mint(msg.sender, _after.sub(_before));
    }

    /**
     * @notice Withdraw from strategy
     * @param _shares A list that contains shares to withdraw
     * @dev amount _shares = amount daoToken
     * Requirements:
     * - Only EOA account can call this function
     */
    function withdraw(uint256[] memory _shares) external {
        require(!address(msg.sender).isContract(), "Only EOA");
        
        uint256 _before = strategy.balanceOf(address(this));
        strategy.withdraw(_shares);
        uint256 _after = strategy.balanceOf(address(this));

        _burn(msg.sender, _before.sub(_after));
    }

    /**
     * @notice Refund from strategy
     * @notice This function usually only available when strategy in vesting state
     * Requirements:
     * - Only EOA account can call this function
     * - Amount dvmToken of user must greater than 0
     */
    function refund() external {
        require(!address(msg.sender).isContract(), "Only EOA");

        uint256 _shares = balanceOf(msg.sender);
        require(_shares > 0, "No balance to refund");

        uint256 _before = strategy.balanceOf(address(this));
        strategy.refund(_shares);
        uint256 _after = strategy.balanceOf(address(this));

        _burn(msg.sender, _before.sub(_after));
    }

    /**
     * @notice Set pending strategy
     * @param _pendingStrategy Address of pending strategy
     * Requirements:
     * - Only owner of this contract call this function
     * - Pending strategy must be a contract
     */
    function setPendingStrategy(address _pendingStrategy) external onlyOwner {
        require(canSetPendingStrategy, "Cannot set pending strategy now");
        require(_pendingStrategy.isContract(), "New strategy is not contract");

        pendingStrategy = _pendingStrategy;
    }

    /**
     * @notice Unlock function migrateFunds()
     * Requirements:
     * - Only owner of this contract call this function
     */
    function unlockMigrateFunds() external onlyOwner {
        unlockTime = block.timestamp + LOCKTIME;
        canSetPendingStrategy = false;
    }

    /**
     * @notice Migrate all funds from old strategy to new strategy
     * Requirements:
     * - Only owner of this contract call this function
     * - Calling this function within unlock time
     * - Pending strategy is set
     */
    function migrateFunds() external onlyOwner {
        require(unlockTime <= block.timestamp && unlockTime + 1 days >= block.timestamp, "Function locked");
        require(pendingStrategy != address(0), "No pendingStrategy");

        uint256 _amount = token.balanceOf(address(strategy));
        require(_amount > 0, "No balance to migrate");

        token.safeTransferFrom(address(strategy), pendingStrategy, _amount);
        // Remove balance of old strategy token
        IERC20Upgradeable oldStrategyToken = IERC20Upgradeable(address(strategy));
        oldStrategyToken.safeTransfer(address(strategy), oldStrategyToken.balanceOf(address(this)));

        address oldStrategy = address(strategy);
        strategy = IStrategyUpgradeable(pendingStrategy);
        pendingStrategy = address(0);
        canSetPendingStrategy = true;

        unlockTime = 0; // Lock back this function

        emit MigrateFunds(oldStrategy, address(strategy), _amount);
    }
}