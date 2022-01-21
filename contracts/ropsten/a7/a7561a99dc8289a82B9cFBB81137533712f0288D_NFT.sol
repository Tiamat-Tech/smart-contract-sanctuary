// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC721PresetMinterPauserAutoId {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    uint256 public price;
    uint256 public maxPerMint;
    uint256 public maxSupply;
    bool public hidden = true;
    string public _hiddenTokenURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        string memory hiddenTokenURI,
        uint256 _price,
        uint256 _maxPerMint,
        uint256 _maxSupply
    )
    ERC721PresetMinterPauserAutoId(name, symbol, baseTokenURI)
    {
        price = _price;
        maxPerMint = _maxPerMint;
        maxSupply = _maxSupply;
        _hiddenTokenURI = hiddenTokenURI;
    }

    function mintSale(uint256 quantity) public payable {
        require(!paused(), "Token is currently paused");
        require(quantity <= maxPerMint, "Quantity is too high: see maxPerMint");
        require(msg.value >= quantity * price, "Value is too low: see price");
        require(_tokenIdTracker.current() + quantity <= maxSupply, "Supply is too low");
        for(uint i; i < quantity; i++) {
            _tokenIdTracker.increment();
            _safeMint(_msgSender(), _tokenIdTracker.current());
        }
    }

    function withdraw() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Unauthorized");
        payable(_msgSender()).transfer(address(this).balance);
    }

    function unHide() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Unauthorized");
        hidden = false;
    }

    function updateMaxPerMint(uint256 _maxPerMint) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Unauthorized");
        maxPerMint = _maxPerMint;
    }

    function updatePrice(uint256 _price) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Unauthorized");
        price = _price;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_tokenIdTracker.current() >= tokenId, "Token doesn't exist");
        if(hidden) {
            return _hiddenTokenURI;
        }
        return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId)));
    }

    function available() public view returns (uint256) {
        return maxSupply - _tokenIdTracker.current();
    }
}