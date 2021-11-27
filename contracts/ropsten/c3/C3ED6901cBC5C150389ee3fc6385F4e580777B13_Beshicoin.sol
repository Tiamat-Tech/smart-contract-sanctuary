// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Beshicoin is ERC20 {

    address private owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Unauthorized");
        _;
    }

    constructor(string memory name,string memory symbol,uint totalSupply) ERC20(name,symbol) {
        owner = msg.sender;
        _mint(msg.sender, totalSupply * 10 ** uint(decimals()));
    }

    function burn(uint amount) public onlyOwner {
        _burn(msg.sender, amount);
    }

    function getSenderAddress() view public returns(address) {
        return(msg.sender);
    }
}