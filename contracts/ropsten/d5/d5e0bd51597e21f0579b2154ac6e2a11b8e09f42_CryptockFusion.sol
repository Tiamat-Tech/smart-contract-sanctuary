// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CryptockFusion is ERC721, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdCounter;

    EnumerableSet.AddressSet private _supportedNFTs;

    string public baseURI;

    constructor() ERC721("Cryptock Fusion", "Cryptock Fusion") {}

    function canFuse(address upgradeableNFT, uint256 tokenIDToUpgrade) public view returns (bool) {
        require(_supportedNFTs.contains((upgradeableNFT)), "Cannot fuse an unsupported NFT");
        
        IERC721 upgradeable = IERC721(upgradeableNFT);
        require(upgradeable.ownerOf(tokenIDToUpgrade) == _msgSender(), "Message Sender doesn't meet the requirements");

        uint256 holding = IERC721(upgradeableNFT).balanceOf(_msgSender());
        uint256 fusion = balanceOf(_msgSender());

        return (holding >= 2 && fusion >= 1);
    }

    function fuse(address upgradeableNFT, uint256 fusionToBurnIndex, uint256 tokenIDToUpgrade, string memory attribute, string memory keepValue) public {
        require(canFuse(upgradeableNFT, tokenIDToUpgrade), "Message Sender doesn't meet the requirements");
        require(ownerOf(fusionToBurnIndex) == _msgSender(), "Message Sender doesn't meet the requirements");

        _burn(fusionToBurnIndex);

        emit Fused(_msgSender(), upgradeableNFT, tokenIDToUpgrade, attribute, keepValue);
    }

    // ------------------------------------------------- getters and setters
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string calldata _tokenBaseURI) external onlyOwner {
        baseURI = _tokenBaseURI;
        emit ChangeBaseURI(_tokenBaseURI);
    }


    function addSupportedNFT(address toSupport) public onlyOwner {
        _supportedNFTs.add(toSupport);
        emit SupportedNFTAdded(toSupport);

    }

    function removeSupportedNFT(address toRemove) public onlyOwner {
        _supportedNFTs.remove(toRemove); 
        emit SupportedNFTRemoved(toRemove);
    }

    
    // ------------------------------------------------- events
    event Fused(address holder, address upgradeableNFT, uint256 tokenIDToUpgrade, string attribute, string keepValue);
    event ChangeBaseURI(string _baseURI);
    event SupportedNFTAdded(address added);
    event SupportedNFTRemoved(address removed);


    // ------------------------------------------------- ERC-721
    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }
}