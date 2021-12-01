pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './Mintable.sol';

contract TestToken is Mintable {
    constructor()
        ERC20("TestToken", "TST") public {
    }

}