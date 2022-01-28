//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    bool canSale = false;

    constructor() public ERC721("MyNFT", "NFT") {}


    function startSale() public onlyOwner
    {
        canSale = true;
    }
    
    function stopSale() public onlyOwner
    {
        canSale = false;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "http://localhost:8080/metadata/";
    }

    function mintNFT(address recipient, string memory tokenURI) public
        returns (uint256)
    {
        require(canSale);
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        
        return newItemId;
    }
}