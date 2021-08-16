// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";

contract OMIToken is AccessControl, ERC20Burnable, ERC20Capped, ERC20Pausable {
    using SafeERC20 for ERC20;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor() ERC20("OMI Token", "OMI") ERC20Capped(750000000000 * 1e18) {
        super._setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        super._setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
        super._setRoleAdmin(PAUSER_ROLE, ADMIN_ROLE);
        super._setupRole(ADMIN_ROLE, msg.sender);
        super._setupRole(MINTER_ROLE, msg.sender);
        super._setupRole(PAUSER_ROLE, msg.sender);
    }

    function isOMITokenContract() public pure returns (bool) {
        return true;
    }

    function pause() public virtual onlyRole(PAUSER_ROLE) {
        super._pause();
    }

    function unpause() public virtual onlyRole(PAUSER_ROLE) {
        super._unpause();
    }

    function mint(address to, uint256 amount)
        public
        virtual
        onlyRole(MINTER_ROLE)
    {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        virtual
        override(ERC20, ERC20Capped)
    {
        super._mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}