// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TestTokenSameTokenURI is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    event AccessoryEdit(
        uint256 indexed accessoryIndex,
        bool isActive,
        string ipfsUrl,
        uint256 saleCount,
        uint256 saleLimit
    );

    struct Accessory {
        bool isActive;
        string ipfsUrl;
        uint256 saleCount;
        uint256 saleLimit;
    }

    mapping(uint256 => Accessory) public accessories;

    constructor() ERC721("TestTokenSameTokenURI", "TTSTI") {}

    function manageAccessory(
        uint256 _accessoryIndex,
        string memory _ipfsUrl,
        uint256 _saleCount,
        uint256 _saleLimit,
        bool _isActive
    )
    external
    onlyOwner
    {
        accessories[_accessoryIndex].ipfsUrl = _ipfsUrl;
        accessories[_accessoryIndex].saleCount = _saleCount;
        accessories[_accessoryIndex].saleLimit = _saleLimit;
        accessories[_accessoryIndex].isActive = _isActive;

        emit AccessoryEdit(
            _accessoryIndex,
            _isActive,
            _ipfsUrl,
            _saleCount,
            _saleLimit
        );
    }

    function safeMint(uint256 accessoryIndex, address to) public onlyOwner {
        require(
            accessories[accessoryIndex].isActive == true,
            'Accessory inactive'
        );
        require(
            accessories[accessoryIndex].saleLimit > accessories[accessoryIndex].saleCount,
            'Accessory sold-out'
        );

        _safeMint(to, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), accessories[accessoryIndex].ipfsUrl);
        _tokenIdCounter.increment();
        accessories[accessoryIndex].saleCount++;
    }

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId)
    internal
    override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function currentCounter() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function freeMint(address to, string memory nftTokenURI) public {
        _safeMint(to, _tokenIdCounter.current());
        _setTokenURI(_tokenIdCounter.current(), nftTokenURI);
        _tokenIdCounter.increment();
    }
}