// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

contract DNFT is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => string) public tokenURIs;
    mapping(uint256 => string) public lowtokenURIs;
    mapping(uint256 => string) public hightokenURIs;
    mapping(uint256 => string) public raretokenURIs;

    event CreatedFeedsNFT(uint256 indexed tokenId);

    constructor() ERC721("DNFT", "DNFT") public {    }

    function evolve(uint256 tokenId) public onlyOwner {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if(keccak256(bytes(raretokenURIs[tokenId])) == keccak256(bytes(tokenURIs[tokenId]))){
            tokenURIs[tokenId] = lowtokenURIs[tokenId];
        }
        if(keccak256(bytes(hightokenURIs[tokenId])) == keccak256(bytes(tokenURIs[tokenId]))){
            tokenURIs[tokenId] = raretokenURIs[tokenId];
        }
        else{
            tokenURIs[tokenId] = hightokenURIs[tokenId];
        }
    }

    function mintNFT(address recipient, string memory tokenURI, string memory evolvedtokenURI, string memory raretokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        lowtokenURIs[newItemId] = tokenURI;
        hightokenURIs[newItemId] = evolvedtokenURI;
        raretokenURIs[newItemId] = raretokenURI;
        tokenURIs[newItemId] = tokenURI;
        return newItemId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return tokenURIs[tokenId];
    }
}