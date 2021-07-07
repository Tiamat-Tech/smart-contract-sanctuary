//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MinhToken is ERC20 {
    constructor() ERC20("MinhToken", "MTK") {
       _mint(msg.sender, 10000 * (10 ** 18));
    }
     function faucet (address recipient , uint amount) external {
      _mint(recipient, amount);
    }
}