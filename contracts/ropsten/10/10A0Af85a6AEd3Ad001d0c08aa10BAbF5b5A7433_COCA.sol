// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract COCA is
    ERC721Enumerable,
    ERC721Holder,
    IERC2981,
    Ownable,
    Pausable
{
    using Counters for Counters.Counter;
    Counters.Counter private currentTokenId;

    uint256 public constant maxMintAmount = 5;
    uint256 public constant maxSupply = 1444;
    uint256 public constant mintPrice = 0.05 ether;

    constructor() ERC721("Conversation Cats", "COCA") {
        _pause();
    }

    function mint(uint256 _mintAmount) public payable whenNotPaused {
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(_mintAmount <= maxMintAmount);
        require(supply < maxSupply, "Max supply reached.");
        require(supply + _mintAmount <= maxSupply, "Request would exceed max supply.");
        require(msg.value >= mintPrice * _mintAmount, "Insufficient payment amount.");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }  

    function mintReserves(uint256 _mintAmount) public onlyOwner {
        uint256 supply = totalSupply();
        require(_mintAmount > 0);
        require(_mintAmount < 50);
        require(supply + _mintAmount <= maxSupply, "Request would exceed max supply.");

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(msg.sender, supply + i);
        }
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function royaltyInfo(uint256 , uint256 _salePrice) external pure override returns (address, uint256) {
        uint256 royaltyAmount = (_salePrice * 150);
        return (address(0xAbA66F8e2Efd52381d165C7aec8F3D855c10e3e0), royaltyAmount);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return ERC721Enumerable.supportsInterface(interfaceId) || interfaceId == type(IERC165).interfaceId;
    }

    function contractURI() public pure returns (string memory) {
        return "https://arweave.net/yzIOS2TSMMugARZXQssxFZtlIE4iwFezm_xkkU2vIqc/conversation-cats-metadata";
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://arweave.net/93nTEsTTXw4JXVw2QI1yKjCwZLcVpJyojcfeoWQLMlM/";
    }  
}