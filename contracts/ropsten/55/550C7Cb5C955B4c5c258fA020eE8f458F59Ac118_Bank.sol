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
    mapping(address => uint) _balances;

    event Deposit(uint _amount);
    event Transfer(address payable _recipient, uint _amount);

/*
* @notice deposit allows to deposit a value in the contract
* @dev the funds used are fictitious funds and in no case ERC-20
*/
    function deposit(uint _amount) public payable{
        require(_amount > 0, "The amount is to low");
        _balances[msg.sender] += _amount;
        emit Deposit(_amount);
    }

/*
* @notice allows to see the balance in the contract in relation to our user address
*/
    function balanceOf(address _address) external view returns(uint){
        return _balances[_address];
    }

    /*
    * @notice allows you to send funds to any address
* @dev the funds used are fictitious funds and in no case ERC-20
*/
    function transfer(address payable _recipient, uint _amount) public payable{
        require(_amount > 0, "The amount is to low");
        require(msg.sender != _recipient,'transfer only works with an account other');
        require(_balances[msg.sender] >= _amount,"You lack funds");
        require(_balances[_recipient] + _amount >= _balances[_recipient],"nous avons un probleme lors de votre transfer d'argent");

        _balances[msg.sender] -= _amount;
        _balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
    }
}