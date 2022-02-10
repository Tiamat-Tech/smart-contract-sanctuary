// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title Cross the Ages' ERC-20 Smart Contract
 * @author Apps with love AG, [email protected]
 * @notice Cross the Ages' ERC-20 smart contract, whose tokens
 * are used as digital currency in their gaming ecosystem.
 * @dev You can cut out 10 opcodes in the creation-time EVM bytecode
 * if you declare a constructor `payable`. For more in-depth information
 * see here: https://forum.openzeppelin.com/t/a-collection-of-gas-optimisation-tricks/19966/5
 * @custom:security-contact [email protected]
 */

contract CrossTheAges is ERC20, ERC20Permit {
    constructor()
        payable
        ERC20("CrossTheAges", "CTA")
        ERC20Permit("CrossTheAges")
    {
        _mint(msg.sender, 10**9 * 10**decimals());
    }
}