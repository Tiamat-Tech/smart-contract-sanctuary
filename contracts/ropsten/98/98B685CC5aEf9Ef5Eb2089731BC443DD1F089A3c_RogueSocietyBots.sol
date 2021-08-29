pragma solidity ^0.8.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RogueSocietyBots is ERC721Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 private constant _maxTokens = 15777;
    uint256 private constant _maxMint = 25;
    uint256 private constant _maxPresaleMint = 2;
    uint256 public constant _price = 90000000000000000; // 0.09 ETH

    mapping (address => bool) private _whitelist;
    mapping (address => uint256) private _presaleMints;
    bool private _presaleActive = false;
    bool private _saleActive = false;
    
    string public _prefixURI;

    constructor() ERC721("Rogue Society Bots", "RSB") {}

    function _baseURI() internal view override returns (string memory) {
        return _prefixURI;
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        _prefixURI = _uri;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }

    function isWhitelisted(address addr) public view returns (bool) {
        return _whitelist[addr];
    }

    function addToWhitelist(address[] memory addrs) public onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            _whitelist[addrs[i]] = true;
            _presaleMints[addrs[i]] = 0;
        }
    }

    function presaleMintItems(uint256 amount) public payable {
        require(amount <= _maxMint);
        require(isWhitelisted(msg.sender));
        require(_presaleMints[msg.sender] < _maxPresaleMint);
        require(_presaleActive);

        uint256 totalMinted = _tokenIds.current();
        require(totalMinted + amount <= _maxTokens);

        require(msg.value >= amount * _price);

        for (uint256 i = 0; i < amount; i++) {
            _mintItem(msg.sender);
        }
    }

    function mintItems(uint256 amount) public payable {
        require(amount <= _maxMint);
        require(_saleActive);

        uint256 totalMinted = _tokenIds.current();
        require(totalMinted + amount <= _maxTokens);

        require(msg.value >= amount * _price);

        for (uint256 i = 0; i < amount; i++) {
            _mintItem(msg.sender);
        }
    }

    function _mintItem(address to) internal returns (uint256) {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(to, id);

        return id;
    }

    function togglePreSale() public onlyOwner {
        _presaleActive = !_presaleActive;
    }

    function toggleSale() public onlyOwner {
        _saleActive = !_saleActive;
    }

    function toggleTransferPause() public onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function reserve(uint256 quantity) public onlyOwner {
        for(uint i = 0; i < quantity; i++) {
            uint mintIndex = totalSupply();
            if (mintIndex < _maxTokens) {
                _safeMint(msg.sender, mintIndex);
            }
        }
    }

    function withdraw() public payable onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
    }

    // Allows minting(transfer from 0 address), but not transferring while paused()
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        if (!(from == address(0))) {
            require(!paused(), "ERC721Pausable: token transfer while paused");
        }
    }
}