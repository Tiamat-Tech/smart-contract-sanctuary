// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './ERC20Standard.sol';

/**
 * @dev {ERC20} token, including:
 *
 *  - Preminted initial supply
 *  - Ability for holders to burn (destroy) their tokens
 *  - No access control mechanism (for minting/pausing) and hence no governance
 *
 * This contract uses {ERC20Burnable} to include burn capabilities - head to
 * its documentation for details.
 *
 * _Available since v3.4._
 */
contract ERC20FixedSupply is ERC20Standard {
  /**
   * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
   *
   * See {ERC20-constructor}.
   */
   
  constructor(
    address owner,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) ERC20Standard(name, symbol, decimal) {
    _mint(owner, initialSupply);
    
     _totalSupply = initialSupply  *  10  ** uint8(decimal);
  }
  
}