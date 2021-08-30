//SPDX-License-Identifier: centric lol
pragma solidity ^0.8.0;

import "./UpgradableProxy.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract UpgradableLogic is ERC721Upgradeable {
    uint256 testInt;
    uint256 tokenID;
    mapping(address => uint256) public nfts;
    mapping(uint256 => Metadata) public mdata;
    
    struct Metadata {
        string URI;
        uint8 rarity;
    }




    function mintNFT(address owner, string memory _uri, uint8 _rarity) public returns (uint256) {
        _safeMint(owner, tokenID);
        Metadata memory metadata;
        metadata = Metadata(_uri, _rarity);
        mdata[tokenID] = metadata;
        nfts[owner] = tokenID;
        tokenID++;
        return tokenID;
    }

    function getOwner(uint256 _tokenID) public view returns(address) {
        return ownerOf(_tokenID);
    }



    function getTokenID(address owner) public view returns (uint256) {
        return nfts[owner];
    }

    function getTokenCount() public view returns(uint256) {
        return tokenID;
    }

    function getMdata(uint256 _tokenID) public view returns(string memory, uint8) {
        return (mdata[_tokenID].URI, mdata[_tokenID].rarity);
    }

    function hello() public {
        testInt = 5;
    }

    function getInt() public view returns(uint256) {
        return testInt;
    }


    



}