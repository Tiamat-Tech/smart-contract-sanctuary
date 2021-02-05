pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor( uint256 totalSupply,
        string memory name,
        string memory symbol) public ERC20(name, symbol) {
        _setupDecimals(6);
        _mint(msg.sender, totalSupply);
    }
}