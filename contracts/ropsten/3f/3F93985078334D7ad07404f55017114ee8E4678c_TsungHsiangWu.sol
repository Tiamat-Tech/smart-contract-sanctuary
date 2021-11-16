// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TsungHsiangWu is ERC721URIStorage, Pausable {
    using Counters for Counters.Counter;
    Counters.Counter private m_tokenIds;

    constructor() public ERC721("TsungHsiangWu", "NFT") {}

    function mint(address receiver, string memory tokenURI)
        public
        whenNotPaused
        returns (uint256)
    {
        m_tokenIds.increment();
        uint256 newTokenId = m_tokenIds.current();
        _mint(receiver, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        return newTokenId;
    }

    function burn(uint256 tokenId) public whenNotPaused {
        require(_isApprovedOrOwner(msg.sender, tokenId));
        if (exist(tokenId)) {
            _burn(tokenId);
        }
    }

    function pause() public whenNotPaused {
        _pause();
    }

    function unpause() public whenPaused {
        _unpause();
    }

    function exist(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }
}