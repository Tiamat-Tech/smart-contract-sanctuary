// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721URIStorage, ERC721Enumerable, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor(
        address minter,
        address burner,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, minter);
        _setupRole(MINTER_ROLE, minter);
        _setupRole(BURNER_ROLE, burner);
    }

    function reward(address customer, string memory _tokenURI)
        public
        onlyRole(MINTER_ROLE)
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(customer, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        return newItemId;
    }

    function burn(uint256 tokenId) public onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}