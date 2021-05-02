//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
/*import "@openzeppelin/contracts/access/Ownable.sol";*/


contract DirtyNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public mintingWallet;

    constructor() public ERC721("DirtyNFT", "XXXNFT") {}

    function mintNFT(address recipient, string memory tokenURI) public returns (uint256) {
       //require(!mintingWallet[address(msg.sender)], "User has already minted this NFT");
       //require(timecode > 0, "timecode is invalid"); , uint256 timecode
       require(_tokenIds.current() < 300, "NFT Mint limit has been reached");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        mintingWallet[address(msg.sender)] = true;

        return newItemId;
    }

    //returns whether the mint limit has been reached or not
    function mintLimitReached() public view returns (bool) {
        uint256 newItemId = _tokenIds.current();
        if (newItemId >= 300) {
            return (true);
        } else {
            return (false);
        }
    }

    function totalMinted() public view returns (uint256) {
        return _tokenIds.current();
    }

    
}