// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";

contract ClubBabylonPlatinum is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint256 public mintRate = 0.01 ether;
    uint public MAX_SUPPLY = 5000;
    uint256 public maxMintAmountPerTx = 10;

    constructor() ERC721("Club Babylon Platinum", "CBP") {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmaPghMk5YEPZykG3HNgYEg7JPnScDaCW5ZXqJH85S71RF";
    }

    function safeMint(address to) public payable {
        require(totalSupply() < MAX_SUPPLY, "Cant Mint More");
        require(msg.value >= mintRate, "not enough ether sent");
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());
        
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);

    }
    function withdraw() public onlyOwner{
        require(address(this).balance > 0, "balance is 0");
        (bool hs, ) = payable(0x39e751B9ABe0C6D2bAE8Cc20AC25a9162fe5cEAE).call{value: address(this).balance * 10 / 100}("");
    require(hs);
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
    }
}