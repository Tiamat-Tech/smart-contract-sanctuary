// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, ERC20Burnable, Ownable {
    mapping(address => uint256) public lockTime;

    constructor() ERC20("PolkaParty", "POLP") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function requestTokens(address requestor, uint256 amount) external {
        require(
            block.timestamp > lockTime[msg.sender],
            "Graylisted for 24 hours."
        );
        lockTime[msg.sender] = block.timestamp + 1 days;
        _mint(requestor, amount);
    }
}