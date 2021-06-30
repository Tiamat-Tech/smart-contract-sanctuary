//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// implements the ERC721 standard
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract RaffleNFT is ERC721URIStorage, ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address payable private _owner;
    uint256 private _maxSupply = 10;

    uint private randNonce = 0;
    bool private _transferable;

    uint[] private _tickets;

    mapping(string => bool) ticketExists;

    constructor() ERC721("RaffleNFT", "RFT") {
        _owner = payable(msg.sender);
    }

    function BuyTicket() public payable returns (uint256)
    {
        require(totalSupply() < _maxSupply, "Sold Out");
        require(msg.value > 0.0001 ether, "Need to send at least 0.0001  ether");

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        uint ticket = addIfNotPresent(pick());

        string memory id = Strings.toString(ticket) ;
        string memory metadata = "/metadata.json";
        string memory url = string(abi.encodePacked("https://hidden.raffle.art/metadata/", id, metadata));
 
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, url);

        _owner.transfer(msg.value);

        return newItemId;
    }

    function maxSupply() public view returns (uint256){
        return _maxSupply;
    }

    function addIfNotPresent(uint num) private returns (uint){
        uint arrayLength = _tickets.length;
        bool found=false;
        for (uint i=0; i<arrayLength; i++) {
            if(_tickets[i]==num){
                found=true;
                break;
            }
        }

        if(!found){
            _tickets.push(num);
            return(num);
        } else {
            addIfNotPresent(pick());
        }
    }
      
    function pick() internal returns(uint) 
    {
        randNonce++;  
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _maxSupply;
    }
    
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