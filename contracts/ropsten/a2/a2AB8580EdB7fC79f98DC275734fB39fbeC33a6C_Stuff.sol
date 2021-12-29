pragma solidity ^0.8.10;
// SPDX-License-Identifier: MIT
/// @title X
/// @author [email protected]
/// @dev Z

//TODO Verification

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract Stuff is ERC721, ERC721Enumerable, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Base URI
    string private _baseURIextended = "ipfs://Qmf49vgCd8xZyFwbPHC53ixfJ51fFTzKMAPKC1k6MEg5Ts/";
    // Max Tokens
    uint public constant MaxTokens = 10000;

    constructor() ERC721("Stuff", "STF") {}

    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function safeMint(address to ) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        require(tokenId < MaxTokens, "All available tokens have been minted.");
        _safeMint(to, tokenId);
    }
    function supportsInterface(bytes4 interfaceId)
    public onlyOwner
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    whenNotPaused
    override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

}