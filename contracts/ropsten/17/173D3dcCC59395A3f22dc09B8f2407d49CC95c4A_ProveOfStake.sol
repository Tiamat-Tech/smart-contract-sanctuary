//SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;
import '../libraries/SafeMath.sol';
import '../libraries/Demo.sol';
import './interfaces/IERC2917.sol';

contract ProveOfStake is Demo {
    using SafeMath for uint;

    address public interestsToken;

    mapping(address => uint) public stakePool;
    uint public totalSupply;
    
    constructor(address _interestsToken) 
    Demo()
    {
        interestsToken = _interestsToken;
    }

    function stake() payable public returns(uint amount)
    {
        require(msg.value > 0, "INVALID AMOUNT.");
        stakePool[msg.sender] = stakePool[msg.sender].add(msg.value);
        IERC2917(interestsToken).enter(msg.sender, msg.value);
        amount = msg.value;
        totalSupply += amount;
    }

    function unstake(uint _amountOut) public returns(uint amount)
    {
        require(stakePool[msg.sender] >= _amountOut, "INSUFFICIENT AMOUNT.");
        require(_amountOut > 0, "INVALID AMOUNT.");

        IERC2917(interestsToken).exit(msg.sender, _amountOut);
        stakePool[msg.sender] = stakePool[msg.sender].sub(_amountOut);
        payable(msg.sender).transfer(_amountOut);
        amount = _amountOut;
        totalSupply -= amount;
    }


}