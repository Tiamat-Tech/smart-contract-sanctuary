// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Beshicoin is ERC20 {

    address private owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Unauthorized");
        _;
    }

    constructor(string memory name,string memory symbol) ERC20(name,symbol) {
        owner = msg.sender;
        _mint(msg.sender, 100 * 10 ** uint(decimals()));
    }

    function burn(uint amount) public onlyOwner {
        _burn(msg.sender, amount);
    }
}