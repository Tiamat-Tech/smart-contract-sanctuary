//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _issuedCount;

    constructor() public ERC721("MyNFT", "NFT") {}

    function mintNFT(address recipient, string memory word)
        public onlyOwner
        returns (uint256)
    {
        _issuedCount.increment();

        bytes memory _data = bytes(word);

        uint256 newItemId = uint256(sha256(_data));
        _safeMint(recipient, newItemId, _data);

        if (_issuedCount.current() >= 2){
            renounceOwnership();
        }

        return newItemId;
    }
}