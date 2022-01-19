// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/AccessControl.sol";
/**
 * @title ERC721Tradable
 * ERC721Tradeable - ERC721 contract that whitelists a trading address, and has minting functionality.
 */
contract ContractControlList is AccessControl {
    bytes32 public constant CONTROL_LIST_ADMIN_ROLE = keccak256("CONTROL_LIST_ADMIN_ROLE");
    bytes32 public constant LAND_MINTER_ROLE = keccak256("LAND_MINTER_ROLE");
    bytes32 public constant LAND_OWNER_ROLE = keccak256("LAND_OWNER_ROLE");
    bytes32 public constant LAND_MINTER_OWNER_ROLE = keccak256("LAND_MINTER_OWNER_ROLE");

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CONTROL_LIST_ADMIN_ROLE, msg.sender);
    }

    function checkRole(bytes32 role, address account) external view {
        return _checkRole(role, account);
    }
}