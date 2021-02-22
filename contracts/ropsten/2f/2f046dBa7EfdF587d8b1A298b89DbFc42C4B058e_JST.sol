//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract JST is ERC20, Ownable {
    address public Stakbank;

    constructor(uint _totalSupply) ERC20("Jig Stack", "JST", _totalSupply) {
        Stakbank = address(0);
    }

    function verifyStakbank(address bank) external onlyOwner {
        Stakbank = bank;
    }

    modifier onlyStakbank() {
        require(Stakbank == msg.sender);  
        _;
    }
}