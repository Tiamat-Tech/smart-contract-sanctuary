// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/crowdsale/Crowdsale.sol";

contract Presale is Crowdsale {
    uint256 public _rate;
    address payable public _wallet;
    IERC20 public _token;
    constructor(uint256 rate, address payable wallet, IERC20 token) 
    Crowdsale(rate, wallet, token) public {

        _rate = rate;
        _wallet = wallet;
        _token = token;
    } 
}