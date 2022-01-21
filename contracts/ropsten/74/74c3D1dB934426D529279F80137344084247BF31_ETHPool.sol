// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ETHPool is Initializable, AccessControl, UUPSUpgradeable {

    bytes32 public constant TEAM = keccak256("TEAM");

    struct Cycle {
        uint256 accruedRewards;
        uint256 totalDeposits;
    }

    /// @notice total rewards amount;
    uint256 public currentRewards;

    /// @notice total deposits by address in ETH
    mapping (address => uint256) public totalDepositsByAddress;

    /// @dev cycle ID => Cycle data
    mapping (uint256 => Cycle) private _rewardCycles;

    /// @dev current rewards cycle
    uint256 public currentCycle;

    /// @dev address => cycle id => deposits
    mapping(address => mapping(uint256 => uint256)) private _deposits;

    /// @notice total deposits in ETH
    uint256 public totalDeposits;

    /// @dev when using claimRewards function, look for rewards for how many cycles
    uint256 private _claimRewardsHowManyCycles;

    event Deposit(
        address owner,
        uint256 value
    );

    event DepositRewards(
        address sender,
        uint256 value
    );

    constructor() {}

    function initialize() external initializer {
        currentCycle = 1;
        _claimRewardsHowManyCycles = 26;
        _rewardCycles[currentCycle] = Cycle(0,0);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TEAM, msg.sender);
    }

    /// @notice deposit ETH 
    function deposit() external payable {
        require(msg.value > 0, "Value must be greater than 0");
        _deposits[msg.sender][currentCycle] += msg.value;
        _rewardCycles[currentCycle].totalDeposits += msg.value;
        totalDeposits += msg.value;
        totalDepositsByAddress[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice deposit rewards. Can only be called by team members
    function depositRewards() external payable onlyRole(TEAM) {
        require(msg.value > 0, "Value must be greater than 0");
        _rewardCycles[currentCycle].accruedRewards += msg.value;
        currentRewards += msg.value;
        // each time rewards are deposited, change rewards cycle
        _nextCycle();
        emit DepositRewards(msg.sender, msg.value);
    }

    /// @dev change cycle and init cycle data 
    function _nextCycle() internal {
        currentCycle += 1;
        _rewardCycles[currentCycle] = Cycle(0,0);
    }

    /// @notice claim rewards with default range
    function claimRewards() external {
        uint256 cycleFrom;

        if (currentCycle > _claimRewardsHowManyCycles) {
            cycleFrom = currentCycle - _claimRewardsHowManyCycles;
        } else {
            cycleFrom = 1;
        }
        
        uint256 cycleTo = currentCycle;

        _claimRewards(cycleFrom, cycleTo);
    }

    /// @notice claim rewards with custom range
    function claimRewardsRange(uint256 cycleFrom, uint256 cycleTo) external {
        require(cycleFrom > 0, "cycleFrom value too low");
        require(cycleTo <= currentCycle, "cycleTo value too high");

        _claimRewards(cycleFrom, cycleTo);
    }

    /// @dev claim rewards internal function
    function _claimRewards(uint256 cycleFrom, uint256 cycleTo) internal {
        uint256 totalRewards;

        // iterate over cycles, look for deposits and rewards
        for (uint256 cycle = cycleFrom; cycle <= cycleTo; cycle++) {
            uint256 depositAmount = _deposits[msg.sender][cycle];

            // If sender has deposits in a given cycle
            if (depositAmount > 0) {
                uint256 accruedRewards = _rewardCycles[cycle].accruedRewards;

                // If there are rewards, then add the 
                if (accruedRewards > 0) {
                    // add reward
                    uint256 reward = accruedRewards * depositAmount / _rewardCycles[cycle].totalDeposits;
                    totalRewards += reward;
                    
                    // Update values
                    _rewardCycles[cycle].accruedRewards -= reward;
                    currentRewards -= reward;
                } 
                
                // Update values
                _deposits[msg.sender][cycle] = 0;
                _rewardCycles[cycle].totalDeposits -= depositAmount;
                totalDeposits -= depositAmount;
                totalDepositsByAddress[msg.sender] -= depositAmount;

                // Add reward to total rewards
                totalRewards += depositAmount;

            }
        }

        if (totalRewards > 0) {
            payable(msg.sender).transfer(totalRewards);
        }
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

}