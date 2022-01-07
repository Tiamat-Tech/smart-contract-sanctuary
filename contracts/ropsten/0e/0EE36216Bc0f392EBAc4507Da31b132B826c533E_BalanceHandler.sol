//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BalanceHandler is Ownable {

    uint256 public LOW_BALANCE = 500 * 10^18;
    uint256 public MEDIUM_BALANCE = 1000 * 10^18;
    uint256 public HIGH_BALANCE = 1500 * 10^18;

    uint256 public GIANT_BALANCE = 50000 * 10^18;   

    IERC20 public fqOneToken;
    mapping (address => bool) public instructors;

    modifier isInstructor(address _caller) {
        require(instructors[_caller], "You are not an instructor");
        _;  
    }

    event instructorAdded(address indexed from, address indexed to);
    event instructorRemoved(address indexed from, address indexed to);
    event rewardProvided(address indexed to, uint256 amount);
    

    constructor() {

        address fqOneTokenAddress = 0xA016D1308a9C21A6d0785a563ab4C1064df3e11E;
        fqOneToken = IERC20(fqOneTokenAddress);
        
        fqOneToken.approve(msg.sender, GIANT_BALANCE);
        instructors[msg.sender] = true;
    }

    function checkBalance(address _receiver) public view isInstructor(msg.sender) returns(uint256 balance){
        balance = fqOneToken.balanceOf(_receiver);
    }

    function rewardStudent(address _receiver, uint256 _amount) public isInstructor(msg.sender) {
        _amount = _amount * 10^18;
        fqOneToken.transferFrom(msg.sender, _receiver, _amount);
        emit rewardProvided(_receiver, _amount);
    }

    function addInstructor(address _instructor) public isInstructor(msg.sender) {
        instructors[_instructor]=true;
        fqOneToken.approve(_instructor, GIANT_BALANCE);
        emit instructorAdded(msg.sender, _instructor);
    }
    
    function removeInstructor(address _instructor) public isInstructor(msg.sender) {
        instructors[_instructor]=false;
        emit instructorRemoved(msg.sender, _instructor);
    }

}