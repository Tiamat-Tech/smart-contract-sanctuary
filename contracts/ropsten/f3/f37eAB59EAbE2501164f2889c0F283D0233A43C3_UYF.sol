//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract UYF is ERC20PresetMinterPauser {
    constructor(uint256 initialSupply)
        ERC20PresetMinterPauser("Ultra Yield Finance", "UYF")
    {
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public pure override {
        revert("This token is not mintable");
    }
}