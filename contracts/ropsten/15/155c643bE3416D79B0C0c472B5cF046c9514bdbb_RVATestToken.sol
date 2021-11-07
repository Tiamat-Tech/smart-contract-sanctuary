pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RVATestToken is ERC20 {
    constructor() ERC20("RVATestToken", "RVA"){
        _mint(msg.sender, 1000000);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}