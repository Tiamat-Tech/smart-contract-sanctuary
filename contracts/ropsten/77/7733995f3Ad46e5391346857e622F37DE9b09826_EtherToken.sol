pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @title EtherToken is a basic ERC20 Token
*/
contract EtherToken is ERC20, Ownable{

    /**
    * @dev assign totalSupply to account creating this contract
    */
    constructor()  ERC20("AtariToken","CUB"){
        _setupDecimals(5);
        _mint(msg.sender, 100000000000);
    }
}