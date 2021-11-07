pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract KhoiCoin is ERC20 {
    constructor() ERC20("NFT market Coin", "KhoiCoin") {
        _mint(msg.sender, type(uint256).max);
    }
}