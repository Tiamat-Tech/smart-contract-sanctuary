// SPDX-License-Identifier: MIT

// SOLIDITY-COVERAGE
// --------------|----------|----------|----------|----------|----------------|
// File          |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
// --------------|----------|----------|----------|----------|----------------|
//  contracts/   |    97.22 |       70 |      100 |     97.3 |                |
//   DogCoin.sol |    97.22 |       70 |      100 |     97.3 |             99 |
// --------------|----------|----------|----------|----------|----------------|
// All files     |    97.22 |       70 |      100 |     97.3 |                |
// --------------|----------|----------|----------|----------|----------------|


pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract DogCoin is ERC20 {
    
    mapping(address => uint256) private _balances;
    
    uint256 private _totalSupply;
    address[] public holders;
    
    
    event User_Removed(address user);
    event User_Added(address user);


    constructor() ERC20("DogCoin", "DC") {
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);

        bool address_found = false;
        
        for (uint i = 0; i < holders.length; i++) {
        
            if(holders[i] == to){

                address_found = true;

            }    
        }

        if (!address_found){

            holders.push(to);
            emit User_Added(to);

        }

    }

    function getHolders() public view returns (address[] memory) {
        
        return holders;

    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }


    function _mint(address account, uint256 amount) internal virtual override{
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal virtual override{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;
        
        bool address_found = false;
        
        for (uint i = 0; i < holders.length; i++) {

            if(holders[i] == from){

                if (balanceOf(from) == 0) {

                    holders[i] = holders[holders.length - 1];
                    holders.pop();
                    emit User_Removed(from);

                }

            }
        
            if(holders[i] == to){

                address_found = true;

            }    
        }

        if (!address_found){

            holders.push(to);
            emit User_Added(to);

        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }


}