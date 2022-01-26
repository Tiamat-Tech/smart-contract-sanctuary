// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./utils/Base64.sol";

contract MyTestNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => bytes) private tokenData;
    mapping(uint256 => bytes32) private mediaTypes;
    mapping(uint256 => string) private hiddenData;

    constructor() ERC721("MyTestNFT", "MTN") {}

    function mint(address to, bytes calldata image, bytes32 mediaType, string memory data) public returns (uint256) {
        _tokenIds.increment();
        uint256 tid = _tokenIds.current();
        _safeMint(to, tid);

        tokenData[tid] = image;
        mediaTypes[tid] = mediaType;
        hiddenData[tid] = data;
        return tid;
    }

    function mintWithoutExtraData(address to, bytes calldata image) public returns (uint256) {
      return mint(to, image, bytes32("image/png"), "no extra data");
    }

    function getTokenData(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "token with the tokenId does not exist.");
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "only the owner/approved account can view the token data."
        );

        return hiddenData[tokenId];
    }

    function tokenURI(uint256 tokenId) public override view returns (string memory) {
        require(_exists(tokenId), "token with the tokenId does not exist.");

        string memory description = "extra description cannot be shown to other than owner/approved account.";

        if (_isApprovedOrOwner(msg.sender, tokenId)) {
            description = hiddenData[tokenId];
        }

        bytes memory uri = bytes.concat(
          "data:application/json,{\"name\":\"", bytes(name()),
          "\",\"description\":\"",
          bytes(description),
          "\",\"",
          "image\":\"data:image/png;base64,",
          bytes(Base64.encode(tokenData[tokenId])),
          "\"}");

        return string(uri);
    }
}