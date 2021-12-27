//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./openzeppelin/token/ERC721/TestNetERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract NFTToolbox is TestNetERC721, Ownable {
    using Strings for uint256;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet controllers;

    constructor() TestNetERC721("RinkebyEC", "REC") {
        setDataFolder("https://ec-serverapp-staging.herokuapp.com/card/");
    }

    function setDataFolder(string memory _baseURI) public onlyOwner {
        _setBaseURI(_baseURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        // reformat to directory structure as below
        string memory folder = (tokenId % 100).toString();
        string memory file = tokenId.toString();
        string memory slash = "/";
        return string(abi.encodePacked(baseURI(), folder, slash, file, ".json"));
    }

    function mint(uint256 _newItemId) public onlyAllowed {
        require(!_exists(_newItemId), "ERC721: token already exists");
        _mint(msg.sender, _newItemId);
    }

    function mint(uint256 _newItemId, address recipient) public onlyAllowed {
        require(!_exists(_newItemId), "ERC721: token already exists");
        _mint(recipient, _newItemId);
    }

    function batchMint(uint256[] calldata _newItemIds, address recipient) public onlyAllowed {
        for (uint256 i = 0; i < _newItemIds.length; i++) {
            mint(_newItemIds[i], recipient);
        }
    }

    function takeTokenIdAndGiveTo(uint256 tokenId, address to) public onlyAllowed {
        require(_exists(tokenId), "ERC721: token does not exist");
        _takeToken(tokenId, to);
    }

    function controllerAdd(address _addr) public onlyOwner {
        controllers.add(_addr);
    }

    function controllerRemove(address _addr) public onlyOwner {
        controllers.remove(_addr);
    }

    function controllerContains(address _addr) public view returns (bool) {
        return controllers.contains(_addr);
    }

    function controllerAt(uint256 _index) public view returns (address) {
        return controllers.at(_index);
    }

    function controllerLength() public view returns (uint256) {
        return controllers.length();
    }

    modifier onlyAllowed() {
        require(
            msg.sender == owner() ||
            controllers.contains(msg.sender),
            "Not Authorised"
        );
        _;
    }
}