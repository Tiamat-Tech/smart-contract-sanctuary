// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC677.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract XRUNE is ERC777, ERC677, Ownable {
    constructor(address[] memory defaultOperators)
        Ownable()
        ERC777("XRUNE Token", "XRUNE", defaultOperators)
    {
        _mint(defaultOperators[0], 100000000 ether, "", "");
    }

    function mint(uint amount) public onlyOwner {
        require(totalSupply() + amount < 1000000000 ether, "over 1B max supply");
        _mint(owner(), amount, "", "");
    }
}