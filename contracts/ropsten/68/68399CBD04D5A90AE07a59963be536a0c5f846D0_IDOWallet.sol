// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CROWDValidator.sol";

contract IDOWallet is Ownable, CROWDValidator{

    address token_reciever;

    //Don't accept ETH or BNB
    receive () payable external{
        revert();
    }

    event Deposit(address indexed token_contract, uint256 indexed amount);
    event Withdraw(address indexed token_contract, uint256 indexed amount, uint256 indexed id);

    function save(address token_contract) public onlyOwner{
        IERC20 erc20 = IERC20(token_contract);
        uint256 balance = erc20.balanceOf(address(this));

        erc20.transfer(token_reciever, balance);
    }

    //for ticket
    function deposit(address token_contract, uint256 amount) public{
        require(token_reciever != address(0), "deposit: not set token reciever.");
        IERC20(token_contract).transferFrom(msg.sender, token_reciever, amount);
        emit Deposit(token_contract, amount);
    }

    function withdraw(address token_contract, uint256 amount, uint256 id, uint256 expired_at, bytes memory signature) public{
        require(token_reciever != address(0), "withdraw: not set token reciever.");
        address _validator = checkValidator(token_contract);
        verify("withdraw", id, msg.sender, amount, token_contract, expired_at, _validator, signature);
        
        IERC20(token_contract).transferFrom(token_reciever, msg.sender, amount);
        emit Withdraw(token_contract, amount, id);
    }

    function setReciever(address _addr) public onlyOwner {
        token_reciever = _addr;
    }   
    function getReciver()public view returns(address){
        return token_reciever;
    }
}