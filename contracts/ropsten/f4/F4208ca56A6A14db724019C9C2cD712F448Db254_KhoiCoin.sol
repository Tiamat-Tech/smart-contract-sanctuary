pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract KhoiCoin is ERC20 {
    address public owner;
    constructor() ERC20("NFT market Coin", "KhoiCoin") {
        _mint(msg.sender, 1000000 ether);
        owner = msg.sender;
    }
    function getSome(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}