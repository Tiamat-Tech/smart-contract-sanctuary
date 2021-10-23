// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
 * FOR TESTING PURPOSE ONLY!
 * This FAKE USDC token only for development purposes.
 */
contract USDC is ERC20 {
    constructor() ERC20("Test USDC", "USDC") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    // Unlimited minting for testers
    function mint(uint256 amountToMint) public {
        _mint(msg.sender, amountToMint);
    }
}