pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is Context, ERC20 {

    constructor (string memory tokenName, string memory tokenSymbol) public ERC20(tokenName, tokenSymbol) {
        _mint(_msgSender(), 10000000 * (10 ** uint256(decimals())));
    }
}