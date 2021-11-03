// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract ApartmentContract is ERC20 {
    
    address _owner;
    constructor() ERC20("ApartmentContract", "APRTM")
    {
        super._mint(_msgSender(), 100 * 10 ** super.decimals());
        _owner = msg.sender;
    }




    

}