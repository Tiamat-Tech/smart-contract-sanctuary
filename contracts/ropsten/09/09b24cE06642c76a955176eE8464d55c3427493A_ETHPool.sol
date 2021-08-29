pragma solidity ^0.8.4;

import "hardhat/console.sol";


contract ETHPool {

    // List of team addresses that can deposit rewards
    mapping(address => bool) team;
    // List of users that made a deposit
    mapping(address => UserPool) users;

    // Actual state of a user that made a deposit. Deposit and reward could be 0. 
    struct UserPool {
        uint256 deposit;
        uint256 reward;
        bool actualCicle;
        uint256 id;
    }

    // Total deposit
    uint public totalDeposit;

    // Depositories of current cicle
    address[] actualDepositors;

    // Types of withdraws
    enum WithdrawType{ DEPOSIT, REWARD, ALL }

    // Events that will be triggered after interaction
    event DepositETH(address _user, uint256 _deposit);
    event DepositReward(uint256 _totalReward);
    event WithdrawUser(address _user, uint256 _amount, WithdrawType _type);

    constructor() {
        // Creator is added to the team list
        team[msg.sender] = true;
    }

    // User makes a deposit in ETH
    function depositETH() payable public {
        require(msg.value > 0 , "ETH sended must be higher than 0");
        users[msg.sender].deposit += msg.value;
        totalDeposit += msg.value;
        
        if (users[msg.sender].actualCicle == false) {
            users[msg.sender].actualCicle = true;
            actualDepositors.push(msg.sender);
            users[msg.sender].id = actualDepositors.length - 1;
        }

        emit DepositETH(msg.sender, msg.value);
    }

    function isTeam(address _member) public view returns(bool) {
        return(team[_member]);
    }

    modifier onlyTeam(address _member) {
        require(isTeam(_member), "You are not a team member");
        _;
    }

    function depositReward() payable public onlyTeam(msg.sender) {
        require(msg.value > 0 , "ETH sended must be higher than 0");
        require(actualDepositors.length > 0, "No users with deposit");

        for (uint i=0; i < actualDepositors.length ;i++) {
            // Used Multiply before Dividing pattern
            users[actualDepositors[i]].reward += users[actualDepositors[i]].deposit * msg.value / totalDeposit ;
        }

        emit DepositReward(msg.value);
    }

    function removeDepositor(uint _id) private {
        if (actualDepositors.length > 1) {
            // Move the last element into the place to delete
            actualDepositors[_id] = actualDepositors[actualDepositors.length - 1];
            users[actualDepositors[_id]].id = _id;
            // Remove the last element
            actualDepositors.pop();
        } else {
            delete actualDepositors[_id];
        }
    }

    function withdrawUser(uint256 _amount, WithdrawType _type) public {
        require(_amount > 0, "amount must be higher than 0");

        if (_type == WithdrawType.ALL) {
            require(users[msg.sender].reward + users[msg.sender].deposit >= _amount, "not enough in balance");

            uint rest;
            if (users[msg.sender].reward > 0) {
                if (_amount >= users[msg.sender].reward) {
                    rest = _amount - users[msg.sender].reward;
                    users[msg.sender].reward -= (_amount - rest); 
                } else {
                    rest = 0;
                    users[msg.sender].reward -= _amount;
                }
            } else {
                rest = _amount;
            }

            if (rest > 0) {
                users[msg.sender].deposit -= rest; 
                totalDeposit -= rest;
            }

            if (users[msg.sender].deposit == 0 ) {
                users[msg.sender].actualCicle = false;
                removeDepositor(users[msg.sender].id);
            }

            emit WithdrawUser(msg.sender, _amount, WithdrawType.ALL);

        } else if (_type == WithdrawType.DEPOSIT) {
            require(users[msg.sender].deposit >= _amount, "not enough in balance");
            users[msg.sender].deposit -= _amount; 

            if (users[msg.sender].deposit == 0 ) {
                users[msg.sender].actualCicle = false;
                removeDepositor(users[msg.sender].id);
            }

            totalDeposit -= _amount;

            emit WithdrawUser(msg.sender, _amount, WithdrawType.DEPOSIT);

        } else if (_type == WithdrawType.REWARD) {
            require(users[msg.sender].reward >= _amount, "not enough in balance");
            users[msg.sender].reward -= _amount; 

            emit WithdrawUser(msg.sender, _amount, WithdrawType.REWARD);
        }

        // Using transfer is the most safe way to transfer ETH because it avois re-entrancy and reverts if it fails
        payable(msg.sender).transfer(_amount);

    }

    function addMemberTeam(address _newMember) public onlyTeam(msg.sender) {
        team[_newMember] = true;
    }

    function removeMemberTeam(address _member) public onlyTeam(msg.sender) {
        team[_member] = false;
    }

    function showReward() public view returns(uint){
        return(users[msg.sender].reward);
    }

    function showDeposit() public view returns(uint){
        return(users[msg.sender].deposit);
    }



}