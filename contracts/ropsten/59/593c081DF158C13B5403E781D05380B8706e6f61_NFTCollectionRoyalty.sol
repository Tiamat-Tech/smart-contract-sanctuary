// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './erc2981/ERC2981ContractRoyalty.sol';

contract NFTCollectionRoyalty is
    ERC721,
    ERC721Enumerable,
    ERC2981ContractRoyalty,
    Ownable,
    Pausable
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _tokenIdCounter;
    EnumerableSet.UintSet private _tokenIdList;
    mapping(uint256 => string) _tokenIdToTokenURI;

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory recipient,
        uint256[] memory fee
    ) ERC721(_name, _symbol) {
        _tokenIdCounter.increment();

        for (uint256 i = 0; i < recipient.length; i++) {
            _setRoyalty(recipient[i], fee[i]);
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
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

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            'ERC721Metadata: URI query for nonexistent token'
        );
        return _tokenIdToTokenURI[tokenId];
    }

    function setRoyalty(address _recipient, uint256 _fee) public onlyOwner {
        _setRoyalty(_recipient, _fee);
    }

    function safeMint(string memory _tokenURI) public onlyOwner {
        uint256 _tId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _tokenIdToTokenURI[_tId] = _tokenURI;
        _safeMint(msg.sender, _tId);
        _tokenIdList.add(_tId);
    }

    function burn(uint256 tokenId) public onlyOwner {
        require(
            _exists(tokenId),
            'ERC721Metadata: URI query for nonexistent token'
        );
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721Burnable: caller is not owner nor approved'
        );

        delete _tokenIdToTokenURI[tokenId];
        _tokenIdList.remove(tokenId);

        _burn(tokenId);
    }

    function getTotalCount() public view returns (uint256) {
        return _tokenIdList.length();
    }

    function getTotalList() public view returns (uint256[] memory) {
        return _tokenIdList.values();
    }
}