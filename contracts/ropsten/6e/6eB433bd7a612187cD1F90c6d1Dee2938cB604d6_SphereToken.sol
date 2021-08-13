// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../contracts/access/Permission.sol";

contract SphereToken is ERC721, Permission {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("SphereToken", "SPT") Permission() {}

    struct Sphere {
        uint256 id;
        address creator;
        string uri;
    }

    event SphereMinted(
        uint256 tokenId,
        address creator,
        string uri,
        address owner
    );

    mapping(uint256 => Sphere) public Spheres;

    function mintSphere(string memory uri)
        public
        onlyCreator
        returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(msg.sender, newItemId);

        Spheres[newItemId] = Sphere(newItemId, msg.sender, uri);
        emit SphereMinted(newItemId, msg.sender, uri, msg.sender);

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
            "ERC721Metadata: URI query for non-existent token"
        );

        return Spheres[tokenId].uri;
    }
}