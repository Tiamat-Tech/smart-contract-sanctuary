pragma solidity >=0.7.0 <0.9.0;

import {ERC721} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.2.0-solc-0.7/contracts/token/ERC721/ERC721.sol";
import {Counters} from "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/90ed1af972299070f51bf4665a85da56ac4d355e/contracts/utils/Counters.sol";
/**
 * @title someFishes 
 * @dev let's deploy a bunch of shit. Not safe
 */
 
 contract Fishes is ERC721 {
     using Counters for Counters.Counter;
     Counters.Counter private _tokenIds;
     
     constructor() ERC721("Fishes", "FSHS") {}
     
     function fishForAFish(address fisherman, string memory tokenURI) public returns (uint256) {
         _tokenIds.increment();
         
         uint256 newTokenId = _tokenIds.current();
         _mint(fisherman, newTokenId);
         _setTokenURI(newTokenId, tokenURI);
         
         return newTokenId;
     }
 }