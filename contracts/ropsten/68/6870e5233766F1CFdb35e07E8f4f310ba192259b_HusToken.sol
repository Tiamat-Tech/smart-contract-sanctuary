// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HusToken is ERC20 {
    uint8 public _decimals;
    constructor(string memory name, string memory symbol, uint8 _ddecimals) ERC20(name, symbol) {
        _decimals = _ddecimals;
        _mint(msg.sender, 500000 * 10**_decimals);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setupDecimals(uint8 _ddecimals) public {
        _decimals = _ddecimals;
    }
}