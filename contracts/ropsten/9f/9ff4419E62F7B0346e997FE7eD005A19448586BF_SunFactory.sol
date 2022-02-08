// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract Sun is ERC20, ERC20Detailed {
    address public owner;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address _owner
    )   public 
    ERC20Detailed(name, symbol, decimals) {
        owner = _owner;
        _mint(msg.sender, 1000000000000000000000000000);
    }
}

contract SunFactory {
    Sun[] public suns;

    function createSun(string calldata name, 
    string calldata symbol, uint8 decimals, address _owner) external {
        Sun sun = new Sun(name, symbol, decimals, _owner);
        suns.push(sun);
    }
}