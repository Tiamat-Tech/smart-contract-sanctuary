//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CyanVaultTokenV1 is AccessControl, ERC20 {
    bytes32 public constant CYAN_VAULT_ROLE = keccak256("CYAN_VAULT_ROLE");

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(CYAN_VAULT_ROLE) {
        require(to != address(0), "Mint to the zero address");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount)
        public
        onlyRole(CYAN_VAULT_ROLE)
    {
        require(this.balanceOf(from) >= amount, "Balance not enough");
        _burn(from, amount);
    }

    function burnAdminToken(uint256 amount)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(this.balanceOf(msg.sender) >= amount, "Balance not enough");
        _burn(msg.sender, amount);
    }
}