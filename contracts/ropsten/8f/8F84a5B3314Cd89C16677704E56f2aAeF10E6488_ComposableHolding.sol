// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IComposableHolding.sol";
import "../interfaces/IInvestmentStrategy.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract ComposableHolding is IComposableHolding, ReentrancyGuardUpgradeable, AccessControlEnumerableUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant COMPOSABLE_VAULT = keccak256("COMPOSABLE_VAULT");

    mapping(address => bool) public investmentStrategies;

    event FoundsInvested(
        address indexed strategy,
        address indexed admin,
        uint cTokensReceived
    );

    event InvestmentWithdrawn(
        address indexed strategy,
        address indexed admin
    );

    event TokenClaimed(
        address indexed strategy,
        address indexed rewardTokenAddress
    );

    function initialize(address _admin)
    public
    initializer
    {
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setRoleAdmin(COMPOSABLE_VAULT, DEFAULT_ADMIN_ROLE);
    }

    /// @notice External function used by admin of the contract to add uniq role address
    /// @param _role rol of the actor
    /// @param _actor address of the actor
    function setUniqRole(bytes32 _role, address _actor)
    external
    override
    validAddress(_actor)
    onlyAdmin
    {
        uint256 rolesCount = getRoleMemberCount(_role);
        for (uint256 i = 0; i < rolesCount; i++) {
            address _oldRoleAddress = getRoleMember(_role, i);
            revokeRole(_role, _oldRoleAddress);
        }
        grantRole(_role, _actor);
    }

    // @notice External function to transfer tokens by the vault or by admins
    // @param _token ERC20 token address
    // @param _receiver Address of the receiver, vault or EOA
    // @param _amount Amount to transfer
    function transfer(address _token, address _receiver, uint256 _amount)
    external
    override
    validAddress(_token)
    validAddress(_receiver)
    onlyVaultOrAdmin
    whenNotPaused
    {
        require(IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount, "Not enough token in the contract");
        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
    }

    /// @notice External function called in order to allow other party to spend from this contract
    /// @param spender Address of the spender
    /// @param token Address of the ERC20 token
    /// @param amount Amount allow to spend
    function approve(address spender, address token, uint256 amount)
    external
    override
    whenNotPaused
    validAddress(spender)
    onlyVaultOrAdmin
    {
        IERC20Upgradeable(token).safeApprove(spender, amount);
    }

    /// @notice External function called only by the admin to add IInvestmentStrategy supported contracts
    /// @param strategyAddress IInvestmentStrategy contract address
    function addInvestmentStrategy(address strategyAddress)
    external
    onlyAdmin
    validAddress(strategyAddress)
    {
        investmentStrategies[strategyAddress] = true;
    }

    /// @notice External function called by the admin to invest founds in one of the IInvestmentStrategy from the contract
    /// @param investments Array of Investment struct (token address, amount)
    /// @param investmentStrategy Address of the IInvestmentStrategy admin want to use
    /// @param data dynamic data that strategy required
    function invest(IInvestmentStrategy.Investment[] calldata investments, address investmentStrategy, bytes calldata data)
    external
    onlyAdmin
    validAddress(investmentStrategy)
    {
        require(investmentStrategies[investmentStrategy], "Invalid strategy");
        uint investmentsLength = investments.length;
        address contractAddress = address(this);
        for (uint i; i < investmentsLength; i++) {
            IInvestmentStrategy.Investment memory investment = investments[i];
            require(investment.amount != 0 && investment.token != address(0), "Invalid investment");
            IERC20Upgradeable token = IERC20Upgradeable(investment.token);
            require(token.balanceOf(contractAddress) >= investment.amount, "Not enough tokens");
            token.safeApprove(investmentStrategy, investment.amount);
        }

        uint256 mintedTokens = IInvestmentStrategy(investmentStrategy).makeInvestment(investments, data);
        emit FoundsInvested(investmentStrategy, msg.sender, mintedTokens);
    }

    /// @notice External function called by the admin to withdraw investment
    /// @param investments Array of Investment struct (token address, amount)
    /// @param investmentStrategy address of the strategy
    /// @param data dynamic data that strategy required
    function withdrawInvestment(IInvestmentStrategy.Investment[] calldata investments, address investmentStrategy, bytes calldata data)
    external
    onlyAdmin
    validAddress(investmentStrategy)
    {
        require(investmentStrategies[investmentStrategy], "Invalid strategy");
        IInvestmentStrategy(investmentStrategy).withdrawInvestment(investments, data);
        emit InvestmentWithdrawn(investmentStrategy, msg.sender);
    }

    /// @notice External function used to claim tokens that different DAO issues for the investors
    /// @param investmentStrategy address of the strategy
    /// @param data dynamic data that strategy required
    function claim(address investmentStrategy, bytes calldata data)
    external
    onlyAdmin
    validAddress(investmentStrategy)
    {
        require(investmentStrategies[investmentStrategy], "Invalid strategy");
        address rewardTokenAddress = IInvestmentStrategy(investmentStrategy).claimTokens(data);
        emit TokenClaimed(investmentStrategy, rewardTokenAddress);
    }

    function pause() external whenNotPaused onlyAdmin {
        _pause();
    }

    function unpause() external whenPaused onlyAdmin {
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

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admins allowed");
        _;
    }

    modifier onlyVaultOrAdmin() {
        require(hasRole(COMPOSABLE_VAULT, msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Permissions: Not allowed");
        _;
    }
}