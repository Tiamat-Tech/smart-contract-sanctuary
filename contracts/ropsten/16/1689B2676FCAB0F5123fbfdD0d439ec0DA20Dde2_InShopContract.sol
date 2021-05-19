// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// TODO https://medium.com/pinata/how-to-build-erc-721-nfts-with-ipfs-e76a21d8f914

contract InShopContract is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;

    constructor() ERC721("InShop NFT", "INS") {}

    function awardItem(address recipient, string memory hash, string memory metadata)
    public
    returns (uint256)
    {
        require(hashes[hash] != 1);
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        // TODO устаревшая же функция?
        // _setTokenURI(newItemId, metadata);

        return newItemId;
    }

    function _baseURI() internal view override returns (string memory) {
        return 'https://inshop.world/';
    }
}