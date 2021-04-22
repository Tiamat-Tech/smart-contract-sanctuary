// contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RugToken is ERC20("RugToken", "RUG"){
    constructor() public {
        uint256 INITIAL_SUPPLY = 100000000*(10**18);
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}