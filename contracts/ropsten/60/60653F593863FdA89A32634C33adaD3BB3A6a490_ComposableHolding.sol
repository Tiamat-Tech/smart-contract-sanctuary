// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/IComposableHolding.sol";
import "../interfaces/IInvestmentStrategy.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract ComposableHolding is
    IComposableHolding,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant COMPOSABLE_VAULT = keccak256("COMPOSABLE_VAULT");
    bytes32 public constant REBALANCING_BOT = keccak256("REBALANCING_BOT");

    mapping(address => bool) public investmentStrategies;
    mapping(address => uint256) public rebalancingThresholds;

    event FoundsInvested(
        address indexed strategy,
        address indexed admin,
        uint256 cTokensReceived
    );

    event InvestmentWithdrawn(address indexed strategy, address indexed admin);
    event RebalancingThresholdChanged(
        address indexed admin,
        address indexed token,
        uint256 oldAmount,
        uint256 newAmount
    );
    event RebalancingInitiated(
        address indexed by,
        address indexed token,
        address indexed receiver,
        uint256 amount
    );
    event TokenClaimed(
        address indexed strategy,
        address indexed rewardTokenAddress
    );

    function initialize(address _admin) public initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setRoleAdmin(COMPOSABLE_VAULT, DEFAULT_ADMIN_ROLE);
    }

    /// @notice External function used by admin of the contract to define rebalancing max amounts per token
    /// @param _token token address for which we want to set the threshold
    /// @param _amount the max rebalancing amount for that token (max withdrawable amount)
    function setRebalancingThreshold(address _token, uint256 _amount)
        external
        validAddress(_token)
        validAmount(_amount)
        onlyAdmin
    {
        emit RebalancingThresholdChanged(
            msg.sender,
            _token,
            rebalancingThresholds[_token],
            _amount
        );

        rebalancingThresholds[_token] = _amount;
    }

    /// @notice External function used by rebalancing bots to extract liquidity that will be transferred to another layer
    /// @param _token token address for which we want to rebalance
    /// @param _amount the amount that's being extracted
    /// @param _receiver receiver address; has to be whitelisted
    function extractLiquidityForRebalancing(
        address _token,
        uint256 _amount,
        address _receiver
    )
        external
        validAddress(_token)
        validAmount(_amount)
        onlyRebalancingOrAdmin
    {
        require(_amount <= rebalancingThresholds[_token], "Amount too big");

        require(
            IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount,
            "Not enough tokens in the contract"
        );

        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);

        emit RebalancingInitiated(msg.sender, _token, _receiver, _amount);
    }

    /// @notice External function used by admin of the contract to add uniq role address
    /// @param _role role of the actor
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
    function transfer(
        address _token,
        address _receiver,
        uint256 _amount
    )
        external
        override
        validAddress(_token)
        validAddress(_receiver)
        onlyVaultOrAdmin
        whenNotPaused
    {
        require(
            IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount,
            "Not enough token in the contract"
        );
        IERC20Upgradeable(_token).safeTransfer(_receiver, _amount);
    }

    /// @notice External function called in order to allow other party to spend from this contract
    /// @param _spender Address of the spender
    /// @param _token Address of the ERC20 token
    /// @param _amount Amount allow to spend
    function approve(
        address _spender,
        address _token,
        uint256 _amount
    ) external override whenNotPaused validAddress(_spender) onlyVaultOrAdmin {
        IERC20Upgradeable(_token).safeApprove(_spender, _amount);
    }

    /// @notice External function called only by the admin to add IInvestmentStrategy supported contracts
    /// @param _strategyAddress IInvestmentStrategy contract address
    function addInvestmentStrategy(address _strategyAddress)
        external
        onlyAdmin
        validAddress(_strategyAddress)
    {
        investmentStrategies[_strategyAddress] = true;
    }

    /// @notice External function called by the admin to invest founds in one of the IInvestmentStrategy from the contract
    /// @param _investments Array of Investment struct (token address, amount)
    /// @param _investmentStrategy Address of the IInvestmentStrategy admin want to use
    /// @param _data dynamic data that strategy required
    function invest(
        IInvestmentStrategy.Investment[] calldata _investments,
        address _investmentStrategy,
        bytes calldata _data
    ) external onlyAdmin validAddress(_investmentStrategy) {
        require(investmentStrategies[_investmentStrategy], "Invalid strategy");
        uint256 investmentsLength = _investments.length;
        address contractAddress = address(this);
        for (uint256 i; i < investmentsLength; i++) {
            IInvestmentStrategy.Investment memory investment = _investments[i];
            require(
                investment.amount != 0 && investment.token != address(0),
                "Invalid investment"
            );
            IERC20Upgradeable token = IERC20Upgradeable(investment.token);
            require(
                token.balanceOf(contractAddress) >= investment.amount,
                "Not enough tokens"
            );
            token.safeApprove(_investmentStrategy, investment.amount);
        }

        uint256 mintedTokens = IInvestmentStrategy(_investmentStrategy)
            .makeInvestment(_investments, _data);
        emit FoundsInvested(_investmentStrategy, msg.sender, mintedTokens);
    }

    /// @notice External function called by the admin to withdraw investment
    /// @param _investments Array of Investment struct (token address, amount)
    /// @param _investmentStrategy address of the strategy
    /// @param _data dynamic data that strategy required
    function withdrawInvestment(
        IInvestmentStrategy.Investment[] calldata _investments,
        address _investmentStrategy,
        bytes calldata _data
    ) external onlyAdmin validAddress(_investmentStrategy) {
        require(investmentStrategies[_investmentStrategy], "Invalid strategy");
        IInvestmentStrategy(_investmentStrategy).withdrawInvestment(
            _investments,
            _data
        );
        emit InvestmentWithdrawn(_investmentStrategy, msg.sender);
    }

    /// @notice External function used to claim tokens that different DAO issues for the investors
    /// @param _investmentStrategy address of the strategy
    /// @param _data dynamic data that strategy required
    function claim(address _investmentStrategy, bytes calldata _data)
        external
        onlyAdmin
        validAddress(_investmentStrategy)
    {
        require(investmentStrategies[_investmentStrategy], "Invalid strategy");
        address rewardTokenAddress = IInvestmentStrategy(_investmentStrategy)
            .claimTokens(_data);
        emit TokenClaimed(_investmentStrategy, rewardTokenAddress);
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

    modifier onlyRebalancingOrAdmin() {
        require(
            hasRole(REBALANCING_BOT, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Permissions: Not allowed"
        );
        _;
    }

    modifier onlyVaultOrAdmin() {
        require(
            hasRole(COMPOSABLE_VAULT, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Permissions: Not allowed"
        );
        _;
    }
}