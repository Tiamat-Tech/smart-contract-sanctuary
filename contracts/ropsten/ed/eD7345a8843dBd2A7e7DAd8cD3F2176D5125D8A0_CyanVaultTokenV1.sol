//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CyanVaultTokenV1 is AccessControl, ERC20, ReentrancyGuard {
    bytes32 public constant CYAN_VAULT_ROLE = keccak256("CYAN_VAULT_ROLE");

    constructor() ERC20("CyanBlueChipVaultToken", "CDAO") {
        _mint(msg.sender, 100000000);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount)
        public
        nonReentrant
        onlyRole(CYAN_VAULT_ROLE)
    {
        require(to != address(0), "Mint to the zero address");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount)
        public
        nonReentrant
        onlyRole(CYAN_VAULT_ROLE)
    {
        require(from != address(0), "Burn from the zero address");
        _burn(from, amount);
    }
}