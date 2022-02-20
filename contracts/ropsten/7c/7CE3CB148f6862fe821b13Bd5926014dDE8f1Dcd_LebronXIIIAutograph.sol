pragma solidity ^0.8.2;

import "ERC721.sol";
import "Ownable.sol";
import "ERC721URIStorage.sol";

contract LebronXIIIAutograph is Ownable, ERC721URIStorage {
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

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _setTokenURI(tokenId, _tokenURI);
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