pragma solidity ^0.8.0;

/*
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
*/


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HektorCoin is ERC20 {
    constructor() ERC20("HektorCoin", "HEC") {
        uint256 TOTAL_SUPPLY = 100000000e18;
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}