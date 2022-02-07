pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Test721 is ERC721Enumerable, Ownable {
 
    uint256 mintIndex=0;
    constructor() ERC721("Test721", "TEST721") {
        
    }
    
    function mint(uint256 numberOfTokens) public  {
           
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, mintIndex);
            mintIndex++;
        }
    }
}