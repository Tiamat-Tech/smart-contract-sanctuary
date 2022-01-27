// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title An NFT minted by gold.xyz
contract GoldNFT is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    uint256 public immutable maxSupply;
    string internal cid;
    Counters.Counter private tokenIdCounter;

    error MaxNFTNumberReached();

    constructor(
        string memory name,
        string memory symbol,
        string memory cid_,
        uint256 maxSupply_
    ) ERC721(name, symbol) {
        cid = cid_;
        maxSupply = maxSupply_;
    }

    function safeMint(address _to) public onlyOwner {
        uint256 tokenId = tokenIdCounter.current();
        if (tokenId >= maxSupply) revert MaxNFTNumberReached();
        tokenIdCounter.increment();
        _safeMint(_to, tokenId);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "URI query for nonexistent token");
        return string(abi.encodePacked("ipfs://", cid, "/", _tokenId.toString(), ".json"));
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(_from, _to, _tokenId);
    }

    function supportsInterface(bytes4 _interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(_interfaceId);
    }
}