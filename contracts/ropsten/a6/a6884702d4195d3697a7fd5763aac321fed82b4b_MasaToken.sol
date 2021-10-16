// contracts/MasaToken.sol
// SPDX-License-Identifier: MIT
//Using OpenZepplin 3.0 and Truffle
//BP: next we need to add required funtions

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; //added OpenZepplin 3.0 Ownable
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol"; //added OpenZepplin 3.0 Minter and Pauser

contract MasaToken is ERC20PresetMinterPauser, Ownable {
    
    string public _name = "Masa"; //token name
	string public _symbol = "CORN"; //token symbol
	uint8 public _decimals = 18; 
	uint256 private _initialSupply = 1192258185 * (10 ** uint256(decimals())); // mint supply of 1,192,258,185;

    constructor() ERC20PresetMinterPauser(_name, _symbol) {
        _mint(msg.sender, _initialSupply);
    }

    /**
     * @dev Creates `amount` new tokens for `to`.
     *
     * See {ERC20-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 amount) public override {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC20PresetMinterPauser: must have minter role to mint");
        _mint(to, amount);
    }

}