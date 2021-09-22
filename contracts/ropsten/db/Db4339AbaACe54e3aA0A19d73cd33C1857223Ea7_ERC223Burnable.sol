// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC223.sol";

/**
 * @dev Extension of {ERC223} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
contract ERC223Burnable is ERC223Token {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */

     constructor (
        string memory tokenName,
      string memory tokenSymbol,
      uint8 decimalUnits,
      uint256 initialSupply
     ) ERC223Token (name, symbol, decimals, initialSupply){
        _totalSupply = initialSupply * 10**uint256(decimalUnits);
      balances_[msg.sender] = _totalSupply;
      name = tokenName;
      decimals = decimalUnits;
      symbol = tokenSymbol;
     }
    function burn(uint256 _amount) public  {
        balances_[msg.sender] = balances_[msg.sender] - _amount;
        _totalSupply = _totalSupply - _amount;
        
        // bytes memory empty = hex"00000000";
        emit Transfer(address(0), msg.sender, _totalSupply);

    }
}