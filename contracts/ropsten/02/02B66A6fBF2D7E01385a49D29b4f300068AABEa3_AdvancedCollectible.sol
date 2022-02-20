pragma solidity ^0.8.2;

import "ERC721.sol";
import "Ownable.sol";

contract AdvancedCollectible is ERC721, Ownable {
    uint256 public tokenCounter;
    // add other things
    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => string) public requestIdToTokenURI;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    event requestedCollectible(bytes32 indexed requestId); 


    bytes32 internal keyHash;
    uint256 internal fee;
    
    constructor()
    public 
    ERC721("Lebron XIII Autograph", "LBJ13")
    {
        tokenCounter = 0;
    }

    function mintBatch(address to, uint256 count) 
        public
        onlyOwner
    {
        address owner = to;
        for (uint256 i = 0; i < count; i++) {
            uint256 newItemId = tokenCounter;
            _safeMint(owner, newItemId);
            tokenCounter = tokenCounter + 1;
        }
    }
}