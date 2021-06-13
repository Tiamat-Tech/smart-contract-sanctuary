// SPDX-License-Identifier: MIT

// https://docs.soliditylang.org/en/v0.8.0/layout-of-source-files.html#pragma
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract HelloWorldToken is ERC20Capped, ERC20Burnable, ERC20Snapshot, AccessControl {

    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @dev {ERC20-_mint} is used instead of {_mint} in order to prevent TypeError: 
     * "Immutable variables cannot be read during contract creation time." For details, see
     * https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2580
     */
    constructor() ERC20("Hello, World!", "HELLOv2") ERC20Capped(64_000_000 * 10 ** decimals()) {
        // Configure access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);

        // Pre-mint 6,400,000 tokens (10% of total supply)
        ERC20._mint(msg.sender, 6_400_000 * 10 ** decimals());
    }

    function snapshot() public {
        require(hasRole(SNAPSHOT_ROLE, msg.sender));
        _snapshot();
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
    }

    /**
     * @dev Overrides {_mint} function defined in two base classes. See 
     * https://docs.soliditylang.org/en/develop/contracts.html#inheritance
     */
    function _mint(address account, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }
}