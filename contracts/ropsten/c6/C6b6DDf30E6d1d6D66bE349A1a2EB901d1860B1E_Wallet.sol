// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";

contract Wallet {
    //eth
    address constant walletkeeper = 0x2a36727a39Ce7E3894eDAD190b9ec59047e6dF7D; 
    uint8 comission = 1;
    mapping(address => uint256) balance; 
    //tokens
    mapping(address => mapping(address => uint256)) tokensBalance;
    mapping(address => mapping(address => mapping(address => uint256))) tokensAllowance;
    
    //eth
    event Deposit(address indexed owner, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed owner, uint256 amount);
    //tokens
    event ApprovalTokens(address indexed token, address indexed owner, address indexed spender, uint256 amount);
    event DepositTokens(address indexed token, address indexed owner, uint256 amount);
    event TransferTokens(address indexed token, address indexed from, address indexed to, uint256 amount);
    event WithdrawTokens(address indexed token, address indexed owner, uint256 amount);
//eth
    function setComission(uint8 fee) external returns(bool) {
        require(msg.sender == walletkeeper);
        require(fee <= 50, "You can't set comission more than 5%");
        comission = fee;
        return true;
    }
    
    function getAmountMinusComission(uint amount) external view returns (uint) {
        uint amountWithoutComission = amount - (amount * comission / 1000);
        return (amountWithoutComission);
    }
    
    function deposit() external payable returns(bool) {
        balance[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.value);
        return true;
    }
    
    function transfer(address to, uint256 amount) external returns(bool) {
        if (msg.sender != walletkeeper) {
        uint256 comissionAmount = (amount * comission) / 1000;
        require(balance[msg.sender] >= amount + comissionAmount,"insufficient funds to pay");
        balance[msg.sender] -= amount + comissionAmount;
        balance[to] += amount;
        payable(walletkeeper).transfer(comissionAmount);
        }
        else {
            require(balance[msg.sender] >= amount,"insufficient funds to pay");
            balance[msg.sender] -= amount;
            balance[to] += amount;
        }
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function withdraw(uint256 amount) external returns(bool) {
        if (msg.sender != walletkeeper) {
            uint256 comissionAmount = amount * comission / 1000;
            require(balance[msg.sender] >= amount + comissionAmount,"insufficient funds to pay");
            balance[msg.sender] -= amount + comissionAmount;
            payable(walletkeeper).transfer(comissionAmount);   
        }
        else {
            require(balance[msg.sender] >= amount,"insufficient funds to pay");
            balance[msg.sender] -= amount;
        }
        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
        return true;
    }
    
    function balanceOf() external view returns(uint256) {
        return balance[msg.sender];
    }
//tokens    
    function approveToken( address token, address spender, uint256 amount ) external returns(bool) {
        tokensAllowance[token][msg.sender][spender] = amount;
        
        emit ApprovalTokens(token, msg.sender, spender, amount);
        return true;
    }
    
    function depositToken(IERC20 token, uint256 amount) external payable returns(bool) {
        assert(token.transferFrom(msg.sender, address(this), amount));
        tokensBalance[address(token)][msg.sender] += amount; 
        
        emit DepositTokens(address(token), msg.sender, amount);
        return true;
    }   

    function transferToken(address token, address to, uint256 amount) external returns(bool) {
        require(tokensBalance[token][msg.sender] >= amount, "insufficient tokens");
        tokensBalance[token][msg.sender] -= amount;
        tokensBalance[token][to] += amount;
        
        emit TransferTokens(token, msg.sender, to, amount);
        return true;
    }
    
    function transferTokenFrom(IERC20 token, address owner, address to, uint256 amount) external returns(bool) {
        address tokenAddress = address(token);
        require(tokensAllowance[tokenAddress][owner][msg.sender] >= amount, "inadequately allowed");
        require(tokensBalance[tokenAddress][owner] >= amount, "insufficient tokens");
        tokensAllowance[tokenAddress][owner][msg.sender] -= amount;
        tokensBalance[tokenAddress][owner] -= amount;
        tokensBalance[tokenAddress][to] += amount;
        
        emit TransferTokens(tokenAddress, owner, to, amount);
        return true;
    }
    
    function withdrawToken(IERC20 token, uint256 amount) external returns(bool) {
        require(tokensBalance[address(token)][msg.sender] >= amount);
        tokensBalance[address(token)][msg.sender] -= amount;
        assert(token.transfer(msg.sender, amount));
        
        emit WithdrawTokens(address(token), msg.sender, amount);
        return true;
    }
    
    function allowanceToken(address token, address owner, address spender) external view returns(uint256) {
        return tokensAllowance[token][owner][spender];
    }
    
    function balanceOfToken(address token, address owner) external view returns(uint256) {
        return tokensBalance[token][owner];
    }
    
}