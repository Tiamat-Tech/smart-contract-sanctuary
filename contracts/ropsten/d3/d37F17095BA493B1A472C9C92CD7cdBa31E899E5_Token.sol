pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    constructor(uint256 initialSupplyMantissa) ERC20("presale Token", "MOON") {
        _mint(msg.sender, initialSupplyMantissa);
    }

    function mint(uint256 mintAmountMantissa) public {
        _mint(msg.sender, mintAmountMantissa);
    }
}