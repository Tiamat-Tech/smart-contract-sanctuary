// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * TODO - explain all - explain transferOwnership(address newOwner)
 */
contract MistToken is ERC20, Ownable {

    uint256 constant initialSupply = 100000000e18;

    constructor() ERC20("Icewater - Mist", "MIST") {
        mint(_msgSender(), initialSupply);
    }

    /// @dev See {ERC20-decimals}.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /// @notice Mints `value` to the balance of `account`. Restricted to owner.
    /// @param account The address to add mint to.
    /// @param value The amount to mint.
    function mint(address account, uint256 value) public onlyOwner {
        _mint(account, value);
    }

    /// @notice Burns `value` from the balance of `account`. Restricted to owner.
    /// @param account The address to add burn.
    /// @param value The amount to burn.
    function burn(address account, uint256 value) public onlyOwner {
        _burn(account, value);
    }
}