// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract CRCLToken is ERC20, Pausable, AccessControlEnumerable, ERC20Permit, ERC20Votes {
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");
    bytes32 public constant FOUNDATION_CHAIR_ROLE = keccak256("FOUNDATION_CHAIR_ROLE");
    bytes32 public constant FOUNDATION_MEMBER_ROLE = keccak256("FOUNDATION_MEMBER_ROLE");
    bytes32 public constant DEV_LEAD_ROLE = keccak256("DEV_LEAD_ROLE");
    bytes32 public constant DEV_MEMBER_ROLE = keccak256("DEV_MEMBER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("CRCL Token", "CRCL") ERC20Permit("CRCL Token") {
        _mint(msg.sender, 6630000000 * 10 ** decimals());
        _mint(0x39fe1FDFA52a2B93B4e5F56c9b12231653847812, 468000000 * 10 ** decimals());
        _mint(0xaEaf0fB6Fa31BCF6341DEb7976455e757DC9A1E4, 312000000 * 10 ** decimals());
        _mint(0xcFe79dfa177b7Ba9bAe732d7ec44fD55f1FD89BE, 234000000 * 10 ** decimals());
        _mint(0x3f7867D2EB3677768dD716b78E89e5Bf06FFa3C4, 156000000 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CREATOR_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(FOUNDER_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(FOUNDATION_CHAIR_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(FOUNDATION_MEMBER_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(DEV_LEAD_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(DEV_MEMBER_ROLE, 0x39fe1FDFA52a2B93B4e5F56c9b12231653847812);
        _setupRole(PAUSER_ROLE, msg.sender);
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

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}