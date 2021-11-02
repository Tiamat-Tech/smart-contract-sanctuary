// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BirdNFT is ERC721, Ownable {

    // address private CNR;

    constructor () ERC721 ("CHANGE THIS", "AND THIS") Ownable(){// CHANGE THIS AND SAVE!!!!!!!!!!!!!!!!
        // CNR = _CNR;
    }

    function mintMany(uint startIndex, address[] calldata addresses) public onlyOwner(){
        for (uint id=startIndex; id<addresses.length; id++) {
            _safeMint(addresses[id], id);
        }
    }

    function mintMany2(uint startIndex) public onlyOwner(){
        for (uint id=startIndex; id<10; id++) {
            _safeMint(owner(), id);
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return IChromiaNetResolver(0x29d8E29f41F82203b566047b5Ca4CD828F19E8E6).getNFTURI(address(this), tokenId);
    }
}

interface IChromiaNetResolver {
     function getNFTURI(address contractAddress, uint id) external view returns (string memory);
}