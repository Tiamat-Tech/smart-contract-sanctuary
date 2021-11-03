// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @dev Implementation of liquidity Pool.
 */
contract Pool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public mPUNDIX;
    IERC20 public mPURSE;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;

    // events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @dev Initializes the contract
     */
    constructor(address mPUNDIX_, address mPURSE_) {
        mPUNDIX = IERC20(mPUNDIX_);
        mPURSE = IERC20(mPURSE_);
    }

    /**
     * @dev deposit mPUNDIX token for mPURSE token.
     *
     * Solidity ^0.8 has an integrated SafeMath and new error handling for system errors.
     * If you use SafeMath or a similar library, change x.add(y) to x + y, x.mul(y) to x * y etc.
     */
    function deposit(uint256 amount) public virtual nonReentrant {
         require(amount > 0, "Pool: Cannot deposit 0");

         totalSupply += amount;
         balances[msg.sender] += amount;

         // transfer here
         mPUNDIX.safeTransferFrom(msg.sender, address(this), amount);
         emit Staked(msg.sender, amount);

         // transfer to user
         mPURSE.safeTransfer(msg.sender, amount);
    }

    /**
     * @dev withdraw mPURSE token for mPUNDIX token.
     *
     * Solidity ^0.8 has an integrated SafeMath and new error handling for system errors.
     * If you use SafeMath or a similar library, change x.add(y) to x + y, x.mul(y) to x * y etc.
     */
    function withdraw(uint256 amount) public virtual nonReentrant {
         require(amount > 0, "Pool: Cannot withdraw 0");

         totalSupply -= amount;
         balances[msg.sender] -= amount;

         // transfer here
         mPURSE.safeTransferFrom(msg.sender, address(this), amount);

         // transfer to user
         mPUNDIX.safeTransfer(msg.sender, amount);
         emit Withdrawn(msg.sender, amount);
    }
}