// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract diamsale {
    using SafeMath for uint256;

    IERC20 public diamtoken;

    address public towner;

    uint8 public diamdecimal;

    constructor(IERC20 _diamToken, uint8 _supportTokenDecimals) {
        towner = msg.sender;
        diamtoken = _diamToken;
        diamdecimal = _supportTokenDecimals;
    }
    
    function purchase(uint256 amount) public returns (bool) {
        diamtoken.transferFrom(towner, msg.sender, amount.mul(10**diamdecimal));
        return true;
    }

}