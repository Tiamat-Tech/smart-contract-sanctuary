pragma solidity 0.5.11;

import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract TomiToken is ERC20Detailed, ERC20Burnable {
    constructor(address owner)
        public
        ERC20Detailed("TOMI", "TOMI", 18)
    {
        // 1500 M total supply
        _mint(owner, 1500 * 10**(6 + 18));
    }
}