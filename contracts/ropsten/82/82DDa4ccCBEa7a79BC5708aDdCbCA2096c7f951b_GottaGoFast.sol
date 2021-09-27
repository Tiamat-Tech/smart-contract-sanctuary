//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract GottaGoFast is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable _owner;
    uint256 private MAX_SUPPLY = 1000;
    string private baseURI = "https://ipfs.io/ipfs/QmUQVZW3YuqFFLVxGso4c5rBq5kqnCqMJUPfikTAVX19Ub/";

    constructor() ERC721("Gotta Go Fast", "FAST") {
        _owner = payable(msg.sender);
    }

    function getRemaining() public view returns (uint256) {
        return MAX_SUPPLY - _tokenIds.current();
    }
  
    function mintNFT(address recipient) public payable returns (uint256) {
        require(msg.value >= 10**11 wei, "Not enough ETH sent; check price!"); 
        (bool success,) = _owner.call{value: msg.value}("");
        require(success, "Failed to send money");
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(newItemId <= MAX_SUPPLY);
        _mint(recipient, newItemId);
       _setTokenURI(newItemId, string(abi.encodePacked(baseURI, newItemId)));
        return newItemId;
    }
}