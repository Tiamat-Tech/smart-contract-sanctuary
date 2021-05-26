// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './ERC20.sol';
// import './ERC20Mintable.sol';
import './Ownable.sol';

contract JSR is ERC20,Ownable{
    
    constructor(
        uint256 maximumcoin,
        string memory name, 
        string memory symbol, 
        uint8 decimals 
        ) ERC20(name, symbol, decimals){

            _totalSupply = _balances[address(this)] = maximumcoin;
    }
        
        function adminTransfer(uint256 amount, address recipient) public returns (uint256) {
           require(msg.sender == _owner, "ERC20: Only owner can transfer from contract");
           require(amount <= _balances[address(this)], "ERC20: Only less than total contract balance");
           _transfer(address(this), recipient, amount);
           return(_balances[recipient]);
        }
        
        
        function updateTokenName(string memory _newTokenName) public onlyOwner {
            _name = _newTokenName;
        }
        
        function updateTokenSymbol(string memory _newTokenSymbol) public onlyOwner {
            _symbol = _newTokenSymbol;
        }
        
        /**
       * @dev Function to mint tokens
       * @param to The address that will receive the minted tokens.
       * @param amount The amount of tokens to mint.
       * @return A boolean that indicates if the operation was successful.
       */
        function mint(address to, uint256 amount) public onlyOwner returns (bool) {
            _mint(to, amount);
            return true;
        }

}