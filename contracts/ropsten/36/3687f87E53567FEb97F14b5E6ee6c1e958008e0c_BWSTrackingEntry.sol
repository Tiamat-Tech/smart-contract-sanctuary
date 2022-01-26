// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract BWSTrackingEntry is ERC721URIStorage {
    constructor() ERC721("BWSTrackingEntry", "BWSTE") {}

    // address, checksum of the tracking entry, s3 url of entry
    function mint(address _to, uint256 _tokenId, string calldata _uri) public {
        super._mint(_to, _tokenId);
        super._setTokenURI(_tokenId, _uri);
    }
}