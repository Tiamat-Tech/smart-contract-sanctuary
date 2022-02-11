// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockedERC20 is ERC20, Ownable {
    constructor() ERC20("MockedERC20", "MERC") {
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

// deployed address ROPSTEN - 0x46DD197db75DFfC3EC06d3b37588774ac412a271