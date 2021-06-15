// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "../contracts/access/Permission.sol";

contract RareEstateToken is ERC721, Permission {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("RareEstateToken", "RET") Permission() {}

    struct Estate {
        uint256 id;
        address creator;
        string uri;
    }

    event EstateMinted(
        uint256 tokenId,
        address creator,
        string uri,
        address owner
    );
    event EstateTransferred(address from, address to, uint256 tokenId);
    mapping(uint256 => Estate) public Estates;

    function mintEstate(string memory uri)
        public
        hasPermission()
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);

        Estates[newItemId] = Estate(newItemId, msg.sender, uri);
        emit EstateMinted(newItemId, msg.sender, uri, msg.sender);

        return newItemId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return Estates[tokenId].uri;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._transfer(from, to, tokenId);
        emit EstateTransferred(from, to, tokenId);
    }
}