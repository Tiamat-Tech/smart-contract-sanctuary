// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract RichMeka is ERC721Pausable, Ownable {
    using Counters for Counters.Counter;
    using Strings for uint256;

    uint256 private _totalSupply = 10;
    uint256 private _tokenPrice = 0.0001 ether;
    string private _baseTokenURI = "https://richmeka/api/metadata/richmeka/";
    Counters.Counter private _tokenIds;
    mapping(uint256 => string) private _tokenURIs;
    address[] internal _stakeHolders;

    constructor() ERC721("RichMeka", "RM") {
        _pause();
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setTokenPrice(uint256 tokenPrice) external onlyOwner {
        _tokenPrice = tokenPrice;
    }

    function setBaseTokenURI(string memory baseTokenUri) external onlyOwner {
        _baseTokenURI = baseTokenUri;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function mint(uint256 numberOfTokens) external payable {
        require(numberOfTokens <= 10, "Can only mint 10 tokens at a time");
        require(msg.value >= _tokenPrice * numberOfTokens, "Ether value sent is not correct");
        require(_tokenIds.current() + numberOfTokens  <= _totalSupply, "Purchase would exceed max supply of tokens");

        for(uint i = 0; i < numberOfTokens; i++) {
            _tokenIds.increment();
            uint256 tokenId = _tokenIds.current();
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, tokenId.toString());
        }
    }
}