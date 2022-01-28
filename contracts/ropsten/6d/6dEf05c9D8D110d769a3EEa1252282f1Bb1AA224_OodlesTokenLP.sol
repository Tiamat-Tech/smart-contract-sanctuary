//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.5;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


contract OodlesTokenLP is ERC20{

    constructor(uint _number) ERC20("OodlesTokenLP", "OTP"){
        _mint(msg.sender, _number * ( 10 ** (decimals())));
    }

}