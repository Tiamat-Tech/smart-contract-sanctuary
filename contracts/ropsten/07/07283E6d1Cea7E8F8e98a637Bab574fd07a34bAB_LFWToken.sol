// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

// this contract for testing only, not for deploy mainnet or test net
contract LFWToken is ERC20, Ownable {
    constructor() ERC20("USDT", "USDT-Spike") {
        _mint(msg.sender, 10000000000000 * 10**18);
    }

    function mint() external onlyOwner {
        _mint(msg.sender, 10000000000000 * 10**18);
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of lowest token units to be burned.
     */
    function burn(uint256 value) public {
        _burn(msg.sender, value);
    }
}