// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract MyGallery is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _id;

    constructor() ERC721("MyGallery", "MCO") {

    }

    function mint(address owner, string memory cid) public returns (uint256)
    {
        _id.increment();

        uint256 newId = _id.current();
        _mint(owner, newId);
        _setTokenURI(newId, cid);

        return newId;
    }
}