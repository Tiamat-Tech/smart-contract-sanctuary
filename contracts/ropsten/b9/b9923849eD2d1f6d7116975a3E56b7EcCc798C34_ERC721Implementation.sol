// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

// import "./ERC721Signature.sol";

/// @title ERC721 Contract
/// @dev Simple 721 contract with supporting Royalty standard
/// @dev Using ERC721ignature for sign mint operation

contract ERC721Implementation is AccessControlUpgradeable, ERC721Upgradeable {
    bytes32 public constant SIGNER_ERC721_ROLE =
        keccak256("SIGNER_ERC721_ROLE");
    bytes32 public constant OWNER_ERC721_ROLE = keccak256("OWNER_ERC721_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function init(string memory _name, string memory _symbol)
        external
        returns (bool)
    {
        __ERC721_init(_name, _symbol);

        // _setupRole(OWNER_ERC721_ROLE, msg.sender);
        // _setRoleAdmin(OWNER_ERC721_ROLE, OWNER_ERC721_ROLE);
        // _setRoleAdmin(SIGNER_ERC721_ROLE, OWNER_ERC721_ROLE);
        // _setRoleAdmin(MARKETPLACE_ROLE, OWNER_ERC721_ROLE);
        return true;
    }
}