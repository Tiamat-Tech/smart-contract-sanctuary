//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking {
    using SafeMath for uint;

    IERC20 public stakingToken;
    uint public totalStaked;
    mapping(address => uint) public balances;

    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
    }

    function stake(uint _amount) external {
        require(_amount > 0, "stake::amount must be greater than 0");
        require(stakingToken.balanceOf(msg.sender) >= _amount, "stake::insufficient funds");

        totalStaked = totalStaked.add(_amount);
        balances[msg.sender] = balances[msg.sender].add(_amount);
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint _amount) external {
        require(_amount > 0, "withdraw::amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "withdraw::insufficient funds");

        totalStaked = totalStaked.sub(_amount);
        balances[msg.sender] = balances[msg.sender].sub(_amount);
        stakingToken.transfer(msg.sender, _amount);
    }
}