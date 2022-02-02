//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Skill.sol";

// NullSkill is a still that does nothing 
contract NullSkill is Skill {
    function onRoundStartCallBack(uint256[] memory, uint256[] memory) external pure override {
        return;
    }

    function onDeadCallback(uint256[] memory, uint256[] memory) external pure override {
        return;
    }

    function onDamagedCallback(uint256[] memory, uint256[] memory) external pure override {
        return;
    }
}