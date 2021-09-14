// Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WallStreet is ERC721Pausable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private constant _maxTokens = 8888;
    uint256 private constant _maxMint = 5;
    uint256 public constant _price = 90000000000000000; // 0.09 ETH

    bool private _saleActive = false;
    
    string public _prefixURI;

    constructor() ERC721("WallStreet", "Option") {
        _pause();
    }

    function _baseURI() internal view override returns (string memory) {
        return _prefixURI;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        _prefixURI = _uri;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function mintItems(uint256 quantity) public payable {
        require(quantity <= _maxMint);
        require(_saleActive);

        uint256 totalMinted = _tokenIds.current();
        require(totalMinted + quantity <= _maxTokens);

        require(msg.value >= quantity * _price);

        for (uint256 i = 0; i < quantity; i++) {
            _mintItem(msg.sender);
        }
    }

    function _mintItem(address to) internal returns (uint256) {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(to, id);

        return id;
    }

    function toggleSale() public onlyOwner {
        _saleActive = !_saleActive;
    }

    function toggleTransferPause() public onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function reserve(uint256 quantity) public onlyOwner {
        for(uint i = _tokenIds.current(); i < quantity; i++) {
            if (i < _maxTokens) {
                _tokenIds.increment();
                _safeMint(msg.sender, i + 1);
            }
        }
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    // Allows minting(transfer from 0 address), but not transferring while paused() except from owner
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (!(from == address(0)) && !(from == owner())) {
            require(!paused(), "ERC721Pausable: token transfer while paused");
        }
    }
}