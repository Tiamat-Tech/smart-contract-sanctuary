//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// keeps track of the number of tokens issued
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Accessing the Ownable method ensures that only the creator of the smart contract can interact with it
contract RaffleNFT is ERC721URIStorage, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable private _owner;
    uint256 private _maxSupply = 10;

    // Intializing the state variable
    uint private randNonce = 0;

    // the name and symbol for the NFT
    constructor() ERC721("RaffleNFT", "RFT") {
        _owner = payable(msg.sender);
    }

    // Create a function to mint/create the NFT
    // receiver takes a type of address. This is the wallet address of the user that should receive the NFT minted using the smart contract
    // tokenURI takes a string that contains metadata about the NFT

    function BuyTicket(address player) public payable returns (uint256)
    {
        require(totalSupply() < _maxSupply, "Sold Out");
        require(msg.value > 0.0001 ether, "Need to send at least 0.0001  ether");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        // string memory newItemIdString = Strings.toString(newItemId);
        string memory id = Strings.toString(pick()) ;
        string memory metadata = "/metadata.json";
        string memory url = string(abi.encodePacked("https://hidden.raffle.art/metadata/", id, metadata));
        
        _safeMint(player, newItemId);
        _setTokenURI(newItemId, url);

        _owner.transfer(msg.value);

        // returns the id for the newly created token
        return newItemId;
    }

    function maxSupply() public view returns (uint256){
        return _maxSupply;
    }
      
    // Defining a function to generate
    // a random number
    function pick() internal returns(uint) 
    {
        // increase nonce
        randNonce++;  
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _maxSupply;
    }
    
    // Overrride Functions
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
}