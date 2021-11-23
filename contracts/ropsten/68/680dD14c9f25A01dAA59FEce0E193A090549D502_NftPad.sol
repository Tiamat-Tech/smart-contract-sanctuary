// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NftPad is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    mapping(address => uint256) public userPoints;
    mapping(address => uint256) public stakeToken;
    mapping(address => mapping(address => uint256)) public userStakedBalance;

    event SetTakeToken(address indexed user, address token, uint256 rate);
    event Staked(address indexed user, address token, uint256 amount);
    event UnStaked(address indexed user, address token, uint256 amount);

    function setStakeToken(address token, uint256 ratePoint)
        external
        onlyOwner
    {
        stakeToken[token] = ratePoint;
        emit SetTakeToken(msg.sender, token, ratePoint);
    }

    function stake(address token, uint256 amount) external whenNotPaused {
        require(amount > 0, "Oops!Invalid-amount");
        require(stakeToken[token] != 0, "Oops!Invalid-token");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userStakedBalance[msg.sender][token] = userStakedBalance[msg.sender][
            token
        ].add(amount);
        uint256 point = stakeToken[token].mul(amount);
        userPoints[msg.sender] = userPoints[msg.sender].add(point);
        emit Staked(msg.sender, token, amount);
    }

    function unStake(address token, uint256 amount) external whenNotPaused {
        require(amount > 0, "Oops!Invalid-amount");
        require(stakeToken[token] != 0, "Oops!Invalid-token");
        require(
            userStakedBalance[msg.sender][token] >= amount,
            "Oops!Not-enough-balance-to-unstake"
        );
        IERC20(token).transfer(msg.sender, amount);
        uint256 point = stakeToken[token].mul(amount);
        userPoints[msg.sender] = userPoints[msg.sender].sub(point);
        userStakedBalance[msg.sender][token] = userStakedBalance[msg.sender][
            token
        ].sub(amount);
        emit UnStaked(msg.sender, token, amount);
    }
}