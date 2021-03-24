// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract MockedJackpotToken is ERC20("MockedJackpotToken", "MJT") {
    function mint(address account, uint256 amount) public returns (bool success) {
        _mint(account, amount);
        return true;
    }
}