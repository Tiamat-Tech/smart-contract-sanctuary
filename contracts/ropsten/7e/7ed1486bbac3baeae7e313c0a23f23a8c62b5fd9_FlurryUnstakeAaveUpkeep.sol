//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IFlurryUpkeep.sol";

interface IAaveV2Strategy {
    function emissionPerSecond() external view returns (uint256);

    function shouldActivateCD() external view returns (bool);

    function shouldUnstake() external view returns (bool);

    function claimStkAave() external;

    function activateCD() external;

    function claimAaveAndUnstake() external;
}

contract FlurryUnstakeAaveUpkeep is OwnableUpgradeable, IFlurryUpkeep {
    uint256 public unstakeInterval; // Daily unstake interval with 1 = 1 second
    uint256 public lastTimeStamp;

    IAaveV2Strategy[] public strategies;
    mapping(address => bool) public strategyRegistered;

    /**
     * @dev there are 3 states for stkAAVE interaction
     * 1. NO_ACTION_NEEDED (default: no stkAAVE emission / stkAAVE locked)
     * 2. PENDING_ACTIVATE_CD (never activated cooldown / unstake window expired / just unstaked)
     * 3. PENDING_UNSTAKE (within unstake window)
     */
    enum StakingState {NO_ACTION_NEEDED, PENDING_ACTIVATE_CD, PENDING_UNSTAKE}

    function initialize(uint256 interval) public initializer {
        OwnableUpgradeable.__Ownable_init();
        unstakeInterval = interval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // unstake interval checking and setting
        if ((block.timestamp - lastTimeStamp) < unstakeInterval) return (false, checkData);
        // check stkAave status
        StakingState[] memory stkAaveStates = new StakingState[](strategies.length);
        for (uint256 i; i < strategies.length; i++) {
            if (strategies[i].emissionPerSecond() == 0) continue;
            if (strategies[i].shouldActivateCD()) {
                stkAaveStates[i] = StakingState.PENDING_ACTIVATE_CD;
            } else if (strategies[i].shouldUnstake()) {
                stkAaveStates[i] = StakingState.PENDING_UNSTAKE;
            } else {
                continue; // stkAAVE still in cooldown => NO_ACTION_NEEDED
            }
            upkeepNeeded = true;
        }
        performData = abi.encode(stkAaveStates);
    }

    function performUpkeep(bytes calldata performData) external override {
        lastTimeStamp = block.timestamp;
        StakingState[] memory stkAaveStates = abi.decode(performData, (StakingState[]));
        for (uint256 i = 0; i < strategies.length; i++) {
            // do nothing if stkAAVE is `NO_ACTION_NEEDED`
            if (stkAaveStates[i] == StakingState.PENDING_UNSTAKE) {
                strategies[i].claimAaveAndUnstake();
                stkAaveStates[i] = StakingState.PENDING_ACTIVATE_CD;
            }
            if (stkAaveStates[i] == StakingState.PENDING_ACTIVATE_CD) {
                strategies[i].claimStkAave();
                strategies[i].activateCD();
            }
        }
    }

    function setUnstakeInterval(uint256 interval) external onlyOwner {
        unstakeInterval = interval;
    }

    function registerAaveV2Strategy(address strategyAddr) external onlyOwner {
        require(strategyAddr != address(0), "Strategy address is 0");
        require(!strategyRegistered[strategyAddr], "Strategy already registered");
        strategies.push(IAaveV2Strategy(strategyAddr));
        strategyRegistered[strategyAddr] = true;
    }
}