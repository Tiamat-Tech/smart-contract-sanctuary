// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/[email protected]/security/PausableUpgradeable.sol";
import "@openzeppelin/[email protected]/access/AccessControlUpgradeable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20FlashMintUpgradeable.sol";
import "@openzeppelin/[email protected]/proxy/utils/Initializable.sol";

contract RoxiLink is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC20PermitUpgradeable, ERC20FlashMintUpgradeable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __ERC20_init("RoxiLink", "ROX");
        __ERC20Burnable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC20Permit_init("RoxiLink");
        __ERC20FlashMint_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, 100 * 10 ** decimals());
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}