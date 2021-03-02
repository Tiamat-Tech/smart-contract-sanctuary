// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "./ERC721.sol";
import "./Counters.sol";

contract UniqueAsset is ERC721 {
    
            using Counters for Counters.Counter;
            Counters.Counter private _tokenIds;
            mapping(string => uint8) hashes;
            constructor(string memory myName, string memory mySymbol) ERC721(myName, mySymbol) public {

            }


            function awardItem(address recipient, string memory  hash, string memory metadata)public returns (uint256)
            {
              require(hashes[hash] != 1);
              hashes[hash] = 1;
              _tokenIds.increment();
              uint256 newItemId = _tokenIds.current();
              _mint(recipient, newItemId);
              _setTokenURI(newItemId, metadata);
              return newItemId;
            }

}