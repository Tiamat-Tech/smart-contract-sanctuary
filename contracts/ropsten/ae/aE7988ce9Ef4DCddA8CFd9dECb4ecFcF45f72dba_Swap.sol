// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";

contract Swap {
    mapping (address => IERC20) tokens;
    mapping (address => uint) tokensRate;

    address admin;

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    event TokensPurchased(
      address account,
      address token,
      uint amount,
      uint rate
    );

    event TokensSold(
      address account,
      address token,
      uint amount,
      uint rate
    );

    constructor(address _admin) {
        admin = _admin;
    }

    function setTokenRate(address _token, uint _rate) public onlyAdmin {}

    function tokenRate(address _token) public view returns (uint) {}

    function buyToken(address _token) public payable {}

    function sellToken(address _token, uint _amount) public {}
}