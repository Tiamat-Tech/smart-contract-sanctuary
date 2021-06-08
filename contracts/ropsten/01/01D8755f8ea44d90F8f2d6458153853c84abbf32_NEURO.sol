pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NEURO is ERC20Detailed, ERC20 {
    constructor() public ERC20Detailed("Nahmii EURO", "NEURO", 6) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}