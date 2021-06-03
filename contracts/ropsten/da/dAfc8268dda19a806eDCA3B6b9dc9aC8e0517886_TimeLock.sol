// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MasterChef.sol";

contract TimeLock is Ownable {
	using SafeMath for uint;
    using SafeERC20 for IERC20;

    MasterChef public MASTERCHEF;

    bool public isLocked = true;
    uint public unlockBlock;

    uint constant public UNLOCK_DURATION = 100; // 7,200 blocks = 4 hours

    constructor (address _address) {
        MASTERCHEF = MasterChef(_address);
    }

    function unlock() external onlyOwner {
    	require(isLocked, "TimeLock: NOT_LOCKED");

    	isLocked = false;
    	unlockBlock = (block.number).add(UNLOCK_DURATION);
    }

    function withdraw(IERC20[] memory tokens) external onlyOwner {
    	require(!isLocked, "TimeLock: LOCKED");
    	require(block.number >= unlockBlock, "TimeLock: PENDING_UNLOCK");

    	for (uint i = 0; i < tokens.length; i++) {
    		IERC20 token = tokens[i];
    		token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    	}

    	isLocked = true;
    }

    function updateAddress(address _depositFeeAddress) external onlyOwner {
        require(!isLocked, "TimeLock: LOCKED");
        require(block.number >= unlockBlock, "TimeLock: PENDING_UNLOCK");

        MASTERCHEF.updateDepositFeeAddress(_depositFeeAddress);

        isLocked = true;
    }
}