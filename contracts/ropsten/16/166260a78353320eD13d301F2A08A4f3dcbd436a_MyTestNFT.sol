// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/Base64.sol";

contract MyTestNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) private hiddenData;
    mapping(uint256 => mapping(bool => string)) private tokenUris;

    constructor() ERC721("MyTestNFT", "MTN") {}

    function mint(
        address to,
        bytes calldata image,
        bytes memory mediaType,
        string memory data
    ) public returns (uint256) {
        _tokenIds.increment();
        uint256 tid = _tokenIds.current();
        _safeMint(to, tid);

        hiddenData[tid] = data;
        tokenUris[tid][false] = generateTokenURI(tid, image, mediaType, false);
        tokenUris[tid][true] = generateTokenURI(tid, image, mediaType, true);
        return tid;
    }

    function mintWithoutExtraData(address to, bytes calldata image)
        public
        returns (uint256)
    {
        return mint(to, image, bytes("image/png"), "no extra data");
    }

    function getTokenData(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "token with the tokenId does not exist.");
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "only the owner/approved account can view the token data."
        );

        return hiddenData[tokenId];
    }

    function generateTokenURI(
        uint256 tokenId,
        bytes memory image,
        bytes memory mediaType,
        bool approved
    ) private view returns (string memory) {
        string
            memory description = "extra description cannot be shown to other than owner/approved account.";

        if (approved) {
            description = hiddenData[tokenId];
        }

        bytes memory uri = bytes.concat(
            'data:application/json,{"name":"',
            bytes(name()),
            '","description":"',
            bytes(description),
            '","',
            'image":"data:',
            mediaType,
            ";base64,",
            bytes(Base64.encode(image)),
            '"}'
        );

        return string(uri);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "token with the tokenId does not exist.");

        return tokenUris[tokenId][_isApprovedOrOwner(msg.sender, tokenId)];
    }
}