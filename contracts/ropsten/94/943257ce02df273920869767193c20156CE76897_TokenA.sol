// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title Contract of the token used for the faucet
/// @dev It's an openezeppelin ERC20Capped so there will be a limited supply; It uses openzeppelin AccessControl to specify a minter role (the DjangoApp contract)
contract TokenA is ERC20Capped, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev All the contructor parameters are hard-coded
    constructor() ERC20Capped(1000000 * 1e18) ERC20("TokenA", "TKA") {
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