// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract HCABNFT002 is
    AccessControl,
    ERC1155,
    Pausable,
    Ownable,
    ERC1155Burnable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 public constant CONTRATO_PRINCIPAL = 1;
    uint256 public constant NFT01 = 11;
    uint256 public constant NFT02 = 12;
    uint256 public constant NFT03 = 13;
    string public constant NFT01_NOME = "OBRA DE ARTE 01";
    string public constant NFT02_NOME = "OBRA DE ARTE 02";
    string public constant NFT03_NOME = "OBRA DE ARTE 03";

    constructor() ERC1155("NO_URI") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, CONTRATO_PRINCIPAL, 10**18, "");
        _mint(msg.sender, NFT01, 1, "");
        _mint(msg.sender, NFT01, 1, "");
        _mint(msg.sender, NFT01, 1, "");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function burn(
        address account,
        uint256 tokenId,
        uint256 amount
    ) public override onlyOwner {
        _burn(account, tokenId, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}