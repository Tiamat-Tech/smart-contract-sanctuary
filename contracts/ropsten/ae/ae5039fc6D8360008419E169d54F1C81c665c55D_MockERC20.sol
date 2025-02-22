pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 _initalSupply) public ERC20(name, symbol) {
        _mint(msg.sender, _initalSupply);
    }
}