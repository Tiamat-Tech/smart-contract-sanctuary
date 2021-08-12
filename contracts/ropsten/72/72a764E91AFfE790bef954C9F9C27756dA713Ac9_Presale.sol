pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Uniswap.sol";

contract Presale is AccessControl, ReentrancyGuard {
    bytes32 public constant MANAGER = keccak256("MANAGER");

    address public pasv_token;
    address payable public marketing_wallet;
    address payable public manager_1;
    address payable public manager_2;
    address private uniswapV2Pair;

    uint8 internal constant DECIMALS = 6;
    uint256 internal constant ZEROES = 10**DECIMALS;
    uint256 internal constant TOTAL_SUPPLY = 1000000000 * 10**6 * ZEROES;

    // Total Allocations
    uint256 internal totalLiquidityAmount;
    uint256 internal totalMarketingAmount;

    // Total Tier Allocation
    uint256 internal totalEthTier1 = 0;
    uint256 internal totalEthTier2 = 0;
    uint256 internal totalEthTier3 = 0;

    // Liquidity Deployed Flag
    bool internal liquidityIsDeployed = false;

    // PASV Token Address Set Flag
    bool internal pasvAddressSet = false;

    // Total Presale Pool Amount
    uint256 public totalPresalePoolAmount = 75000000000000 * 10**6;
    // Total Liquidity Pool Amount
    uint256 public totalLiquidityPoolAmount = 500000000000000 * 10**6;

    // Track token launch date and time
    uint256 internal _tokenLaunchTime = 1630522800;

    struct Buyer {
        bool hasDeposited;
        uint256 depositedEthTier1;
        uint256 depositedEthTier2;
        uint256 depositedEthTier3;
        uint256 weightedBalance;
        bool hasClaimed;
    }

    // Track buyers and allocations
    mapping(address => Buyer) public presaleBuyers;
    address[] internal buyerAddresses;

    uint256 public totalAmountWithdrawn = 0;
    uint256 internal totalPresaleWeightedBalance = 0;

    constructor(
        address payable _manager_1,
        address payable _manager_2,
        address payable _marketing
    ) {
        _setupRole(MANAGER, _manager_1);
        _setupRole(MANAGER, _manager_2);

        marketing_wallet = _marketing;
        manager_1 = _manager_1;
        manager_2 = _manager_2;


        totalLiquidityAmount = 0;
        totalMarketingAmount = 0;
    }

    receive() external payable {}

    function getPresaleAmount() public view returns (uint256) {
        return totalPresalePoolAmount;
    }

    function getCurrentTier() public view returns (uint256) {
        uint256 tier1Start = 1628794800;
        uint256 tier1End = 1629399600;
        uint256 tier2Start = 1629399601;
        uint256 tier2End = 1629918000;
        uint256 tier3Start = 1629918001;
        uint256 tier3End = 1630475999;

        if (block.timestamp > tier1Start && block.timestamp < tier1End) {
            return 1;
        } else if (block.timestamp > tier2Start && block.timestamp < tier2End) {
            return 2;
        } else if (block.timestamp > tier3Start && block.timestamp < tier3End) {
            return 3;
        } else {
            return 4;
        }
    }

    function depositEth() external payable nonReentrant {
        // Require msg.value > 0
        require(msg.value > 0);

        // Check mapping if they deposited already
        bool alreadyDeposited = presaleBuyers[msg.sender].hasDeposited; // Ternary necessary? :)

        // If alreadyDeposited == false then add msg.sender to buyerAddresses
        if (!alreadyDeposited) {
            presaleBuyers[msg.sender].hasDeposited = true;

            // Add msg.sender to array
            buyerAddresses.push(msg.sender);
        }

        // Check if total marketing amount has exceeded 100 ETH threshold
        if (totalMarketingAmount < (100 * 10**18)) {
            // Allocate 15% to marketing
            uint256 marketingAllocation = (msg.value * 15) / 100;
            totalMarketingAmount += marketingAllocation;

            // Allocate 85% to liquidity
            uint256 liquidityAllocation = (msg.value * 85) / 100;
            totalLiquidityAmount += liquidityAllocation;

            // Transfer marketing allocation to marketing wallet
            marketing_wallet.transfer(marketingAllocation);
        } else {
            // Allocate 100% to liquidity
            totalLiquidityAmount += msg.value;
        }

        // Check deposited Balance on tier
        uint256 currentTier = getCurrentTier();
        uint256 currentBalance;
        if (currentTier == 1) {
            // Check balance of tier 1
            currentBalance = presaleBuyers[msg.sender].depositedEthTier1;
            presaleBuyers[msg.sender].depositedEthTier1 =
                currentBalance +
                msg.value;
            totalEthTier1 += msg.value;
        } else if (currentTier == 2) {
            // Check balance of tier 2
            currentBalance = presaleBuyers[msg.sender].depositedEthTier2;
            presaleBuyers[msg.sender].depositedEthTier2 =
                currentBalance +
                msg.value;
            totalEthTier2 += msg.value;
        } else if (currentTier == 3) {
            // Check balance of tier 3
            currentBalance = presaleBuyers[msg.sender].depositedEthTier3;
            presaleBuyers[msg.sender].depositedEthTier3 =
                currentBalance +
                msg.value;
            totalEthTier3 += msg.value;
        } else {
            revert("Presale not available");
        }
    }

    function getDepositedEthBalance() external view returns (uint256) {
        // Require msg.sender has deposited
        require(presaleBuyers[msg.sender].hasDeposited == true);
        uint256 tier1Deposit = presaleBuyers[msg.sender].depositedEthTier1;
        uint256 tier2Deposit = presaleBuyers[msg.sender].depositedEthTier2;
        uint256 tier3Deposit = presaleBuyers[msg.sender].depositedEthTier3;
        uint256 totalDepositedBalance = tier1Deposit + tier2Deposit + tier3Deposit;
        return totalDepositedBalance;
    }

    function setPassiveTokenAddress(address _pasv) external {
        // Only callable by admin
        require(hasRole(MANAGER, msg.sender));
        require(_pasv != address(0));
        // Set Passive Token Address
        pasv_token = _pasv;

        // Set Flag to true
        pasvAddressSet = true;
    }

    function deployLiquidity(uint256 tokensToBurn) external {
        // Only callable by admin
        require(hasRole(MANAGER, msg.sender));

        // Check if presale is still active
//        require(_tokenLaunchTime < block.timestamp);

        // Make sure that passive token address has been set
        require(pasvAddressSet == true);

        // Reference PASV token
        IERC20 token = IERC20(pasv_token);
        uint256 contractBalance = token.balanceOf(address(this));

        // Check PASV balance == 575Trillion
        require(contractBalance == (575000000000000 * 10**6));

        // Burn certain amount of tokens based on presale soft cap, can't be more than half.
        require((tokensToBurn * 10**6) <= 37500000000000 * 10**6);
        // Burn Address
        token.transfer(address(0x0000000000000000000000000000000299792458), (tokensToBurn * 10**6));
        totalPresalePoolAmount = totalPresalePoolAmount - (tokensToBurn * 10**6);

        // Calculate Distribution
        calculateDistribution();

        // Update flag
        liquidityIsDeployed = true;

        // Call liquidity deployer contract with liquidityAllocation
        deployInitialLiquidity();
    }

    function calculateDistribution() internal {
        // Loop through buyerAddresses
        for (uint256 i = 0; i < buyerAddresses.length; i++) {
            uint256 balanceTier1 = presaleBuyers[buyerAddresses[i]]
                .depositedEthTier1;
            uint256 balanceTier2 = presaleBuyers[buyerAddresses[i]]
                .depositedEthTier2;
            uint256 balanceTier3 = presaleBuyers[buyerAddresses[i]]
                .depositedEthTier3;
            uint256 totalWeightedBalance = balanceTier1 *
                10 +
                balanceTier2 *
                5 +
                balanceTier3;

            presaleBuyers[buyerAddresses[i]]
                .weightedBalance = totalWeightedBalance;

            totalPresaleWeightedBalance += totalWeightedBalance;
        }
    }

    function claimTokens() external nonReentrant {
        // Check time is after token launch
//        require(_tokenLaunchTime < block.timestamp);

        // Check that liquidity has been deployed
        require(liquidityIsDeployed == true);

        // Require msg.sender has deposited more than 0
        require(presaleBuyers[msg.sender].hasDeposited == true);

        // amount = buyerWeighted / presaleWeighted * pasv_token_pool
        uint256 buyerAmountAvailable = (presaleBuyers[msg.sender]
            .weightedBalance * totalPresalePoolAmount) / totalPresaleWeightedBalance;

        // Set has claimed to true
        presaleBuyers[msg.sender].hasClaimed = true;

        // Update total withdrawn counter
        totalAmountWithdrawn += buyerAmountAvailable;

        // Transfer token to community member
        IERC20 token = IERC20(pasv_token);
        token.transfer(msg.sender, buyerAmountAvailable);
    }

    function deployInitialLiquidity() private {
        // Setup Uniswap Router and create pair
        IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        IERC20 token = IERC20(pasv_token);
        uint256 contractBalance = address(this).balance;
        token.approve(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, TOTAL_SUPPLY);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(pasv_token, uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: contractBalance }(pasv_token,totalLiquidityPoolAmount,totalLiquidityPoolAmount,contractBalance, marketing_wallet, block.timestamp);
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);

        // Send leftover to marketing marketing
        contractBalance = address(this).balance;
        marketing_wallet.send(contractBalance);

    }
}