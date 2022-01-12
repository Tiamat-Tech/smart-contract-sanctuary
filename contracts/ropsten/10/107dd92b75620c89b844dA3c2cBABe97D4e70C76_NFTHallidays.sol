// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';

import './erc2981/ERC2981ContractRoyalty.sol';

contract NFTHallidays is 
    ERC721, 
    ERC721Enumerable, 
    ERC2981ContractRoyalty,
    ERC721URIStorage,
    Ownable 
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _tokenIdCounter;
    EnumerableSet.UintSet private _tokenIdList;

    uint256 public constant PRICE=1e17;

    constructor (
        string memory _name, 
        string memory _symbol
    ) ERC721(_name, _symbol){
        
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC2981Base)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function safeMint(address payable _minter, string memory _tokenURI) public payable {
        require(msg.value==PRICE, "ddddd");
        _minter.transfer(msg.value);
        uint256 _tId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(msg.sender, _tId);
        _setTokenURI(_tId,_tokenURI);
        _tokenIdList.add(_tId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns(string memory)
    {
        return super.tokenURI(tokenId);
    }
}