// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Contract of the token used for the deposit section
/// @dev It's an openzeppelin ERC20Burnable so it's possible to burn; It uses openzeppelin AccessControl to specify a minter role (the DjangoApp contract)
contract TokenB is ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev All the contructor parameters are hard-coded
    constructor() ERC20("TokenB", "TKB") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    /// @dev Only addresses with MINTER_ROLE will be able to use this function
    /// @param to The address that'll receive the tokens
    /// @param amount The amount of tokens received
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}