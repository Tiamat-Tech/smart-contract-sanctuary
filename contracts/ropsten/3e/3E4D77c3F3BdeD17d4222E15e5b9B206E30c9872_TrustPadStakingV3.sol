// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./StakingTreasury.sol";
import "./Stakeable.sol";
import "../levels/IStakingLockable.sol";
import "../levels/ILevelManager.sol";

contract TrustPadStakingV3 is Ownable, IStakingLockable, Stakeable {
    using SafeERC20 for IERC20;

    ILevelManager public levelManager;

    bool public halted = false;

    event LevelManagerSet(address newAddress);
    event Halted(bool status);

    constructor(address _levelManager) Stakeable() {
        levelManager = ILevelManager(_levelManager);
    }

    function isLocked(address account) public view override returns (bool) {
        return
            address(levelManager) != address(0) &&
            levelManager.isLocked(account);
    }

    function getLockedAmount(address account)
        external
        view
        override
        returns (uint256)
    {
        return userInfo[account].amount;
    }

    function setLevelManager(address _levelManager) external onlyOwner {
        levelManager = ILevelManager(_levelManager);
        emit LevelManagerSet(_levelManager);
    }

    function halt(bool status) external onlyOwner {
        halted = status;
        emit Halted(status);
    }

    modifier lockable() {
        require(!isLocked(_msgSender()), "Account is locked");
        _;
    }

    modifier notHalted() {
        require(!halted, "Deposits are paused");
        _;
    }

    function deposit(uint256 amount) public override notHalted {
        super.deposit(amount);
    }

    function withdraw(uint256 amount) public override lockable {
        super.withdraw(amount);
    }

    function withdrawRewards() external onlyOwner {
        treasury.withdrawRewards(rewardToken, _msgSender());
    }
}