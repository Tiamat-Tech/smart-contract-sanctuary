// contracts/Box721.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract BoxOfScript is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Create the token-making contract
    constructor() public ERC721("Lineo", "LINE") {}

    function append(string memory a, string memory b, string memory c, string memory d) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }

    function newBox(address boxOwner, 
                    string memory tokenURI)
        public
        returns (uint256)
        {
            _tokenIds.increment();

            uint256 newBoxId = _tokenIds.current();
        
            
            _safeMint(boxOwner, newBoxId, '<html><svg height="200" width="200" xmlns="http://www.w3.org/2000/svg"><path d="M 10 100 v 80 h 80 v 10 h 20" fill="transparent" stroke="grey"/></svg></html>');
            _setTokenURI(newBoxId, tokenURI);

            return newBoxId;
        }


}