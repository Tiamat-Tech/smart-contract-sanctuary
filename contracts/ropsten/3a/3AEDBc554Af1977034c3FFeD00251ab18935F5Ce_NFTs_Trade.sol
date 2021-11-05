// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTs_Trade is ERC721, ERC721Enumerable, Ownable {
    constructor() ERC721("token", "TTT") {}

    mapping(uint=> uint) coolDownsToTokenIds;
     using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

     uint256 private cdTime = 10;
  
    function safeMint(address to) public returns (uint256) {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
        return _tokenIdCounter.current();
    }

    function mint() public{
        safeMint(msg.sender);
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

    function buy(uint tokenId, address to) public payable{
        require(_isReady(tokenId));
        require(msg.value == 0.0001 ether, "not enough money");
        address _owner = ownerOf(tokenId);
        transferFrom(_owner, to, tokenId);
        coolDownTime(tokenId);
    }

    function coolDownTime(uint tokenId) internal onlyOwner{
        _triggerCooldown(tokenId);
    }

    function _triggerCooldown(uint tokenId) internal {
        coolDownsToTokenIds[tokenId] = uint32(block.timestamp + cdTime);
    }

    function _isReady(uint tokenId) internal view returns (bool) {
         return (coolDownsToTokenIds[tokenId] <= block.timestamp);
    }
}