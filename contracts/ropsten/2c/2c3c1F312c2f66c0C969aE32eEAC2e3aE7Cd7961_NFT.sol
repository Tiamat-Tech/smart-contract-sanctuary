// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721, ERC721Enumerable, ERC721URIStorage, Pausable, Ownable, ERC721Burnable 
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    address passportRedeemContractAddress = 0x45B05E7A4713437224718896673313fF71A3EB38;
    
    constructor() ERC721("Golden Token City 9", "GT9") 
    {
        safeMint(passportRedeemContractAddress, 10);
    }

    function pause() public onlyOwner 
    {
        _pause();
    }

    function unpause() public onlyOwner 
    {
        _unpause();
    }

    function safeMint(address to, uint amount) public 
    {
        for(uint i=0; i<amount; i++)
        {
            _mint(to, _tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal whenNotPaused override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) 
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}