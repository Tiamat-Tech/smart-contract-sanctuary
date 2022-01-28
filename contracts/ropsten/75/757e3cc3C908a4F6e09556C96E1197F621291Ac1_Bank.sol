// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
/*
* @title operation of a simple decentralized bank
* @author nobodyw, https://github.com/nobodyw
* @notice contract allows you to deposit funds, see your balance, withdraw your funds
* @dev the funds used are fictitious funds and in no case ERC-20
*/
contract Bank is Ownable{
    struct Balance {
        address addressUser;
        uint balanceUser;
    }
    Balance[] arrayBalance;

    event Deposit(uint _amount);
    event Transfer(address payable _recipient, uint _amount);

/*
* @notice account owner can see all bank balances
*/
    function getAllBalance() onlyOwner external view returns(Balance[] memory){
        return arrayBalance;
    }

/*
* @notice deposit allows to deposit a value in the contract
* @dev the funds used are fictitious funds and in no case ERC-20
*/
    function deposit(uint _amount) public payable{
        require(_amount > 0, "The amount is to low");
        arrayBalance.push(Balance(msg.sender,_amount));
        emit Deposit(_amount);
    }

/*
* @notice allows to see the balance in the contract in relation to our user address
*/
    function balanceOf(address _address) external view returns(uint){
        for (uint i = 0; i < arrayBalance.length; i++){
            if(arrayBalance[i].addressUser == _address){
                return arrayBalance[i].balanceUser;
            }
        }
        return 0;
    }

/*
* @notice allows you to send funds to any address
* @dev the funds used are fictitious funds and in no case ERC-20
*/
    function transfer(address payable _recipient, uint _amount) public payable{
        require(_amount > 0, "The amount is to low");
        require(msg.sender != _recipient,'transfer only works with an account other');

        for (uint i = 0; i < arrayBalance.length; i++){
            if(arrayBalance[i].addressUser == msg.sender){
                require(arrayBalance[i].balanceUser >= _amount, "You lack funds");
                arrayBalance[i].balanceUser -= _amount;
            }
            if(arrayBalance[i].addressUser == _recipient){
                require(arrayBalance[i].balanceUser + _amount >= arrayBalance[i].balanceUser,"We have a problem during your money transfer");
                arrayBalance[i].balanceUser += _amount;
            }
        }
        emit Transfer(_recipient, _amount);
    }
}