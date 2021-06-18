// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";

// This Token is an ERC20 token representing a different asset wrapped by Celsius

contract Token is ERC20, Ownable, Pausable {

    uint8 private _decimals;

    constructor (string memory name, string memory symbol, uint8 num_decimals) ERC20(name, symbol) {
        _decimals = num_decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // The Token Owner uses this function to create wrapped tokens for a customer
    function mintForCustomer (address customer, uint256 amount) public onlyOwner() {

        // TODO:
        // If we implement Chainlink's Proof Of Reserves, the call to the oracle
        // that keeps us honest would be placed here

        _mint(customer, amount * (10 ** uint256(decimals())));
    }

    // The Token Owner uses this function to destroy wrapped tokens for a customer
    function burnForCustomer (address customer, uint256 amount) public onlyOwner() {
        _burn(customer, amount * (10 ** uint256(decimals())));
    }

}