// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sex is ERC20 {
    constructor() ERC20("SEX", "SEX") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }
}

contract sexWallet {
    address public sexW;

    constructor() {
        sexW = msg.sender;
    }

    receive() external payable {}

    modifier onlyCaller() {
        require(msg.sender == sexW, "not owner");
        _;
    }

    function withdraw(uint _amount) external onlyCaller {
        payable(msg.sender).transfer(_amount);
    }

    function getBal() external view returns (uint) {
        return address(this).balance;
    } 
}