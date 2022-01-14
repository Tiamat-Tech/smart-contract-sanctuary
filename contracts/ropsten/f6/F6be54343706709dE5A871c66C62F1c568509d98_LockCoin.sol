// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract LockCoin is Ownable {

    address payable public feeReceiver;

    uint256 public fee = 0.001 ether;

    struct TokenLocked {
        address token;
        address owner;
        uint256 tokenAmount;
        uint256 unlockTime;
    }

    uint256 public lockNonce = 0;

    mapping(uint256 => TokenLocked) public tokenLocks;

    constructor() {
        feeReceiver = payable(msg.sender);
    }

    function lockTokens(address token, uint256 amount, uint256 unlockTime,
            address owner) external returns (uint256 lockId) {
        TokenLocked memory lock = TokenLocked({
            token: token,
            owner: owner,
            tokenAmount: amount,
            unlockTime: unlockTime
        });

        lockId = lockNonce++;
        tokenLocks[lockId] = lock;

        feeReceiver.transfer(fee);

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        return lockId;
    }

    function withdraw(uint256 lockId) external {
        TokenLocked memory lock = tokenLocks[lockId];
        withdrawPartially(lockId, lock.tokenAmount);
    }

    function withdrawPartially(uint256 lockId, uint256 amount) public {
        TokenLocked memory lock = tokenLocks[lockId];
        require(block.timestamp >= lock.unlockTime, "NOT YET UNLOCKED");
        require(lock.owner == address(msg.sender), "NOT OWNER");
        IERC20(lock.token).transfer(lock.owner, lock.tokenAmount);
        lock.tokenAmount = lock.tokenAmount - amount;
    }

}