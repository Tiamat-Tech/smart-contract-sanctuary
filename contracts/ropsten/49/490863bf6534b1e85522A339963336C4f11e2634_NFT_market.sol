pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT_market is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _allNFT;    

    event NftBought(address _seller, address _buyer, uint256 _price);
    mapping (uint256 => uint256) public tokenIdToPrice;

    constructor() ERC721('NFT_market', 'NFT_M') {}

    function mintNFT(string memory tokenURI) public returns(uint256){
        _allNFT.increment();
        uint256 newItemID = _allNFT.current();
        _mint(msg.sender,newItemID);
        _setTokenURI(newItemID,tokenURI);
        tokenIdToPrice[newItemID] = 0;
        return newItemID;
    }

    function allowBuy(uint256 _tokenId, uint256 _price) external {
        require(msg.sender == ownerOf(_tokenId), 'Not owner of this token');
        require(_price > 0, 'Price zero');
        tokenIdToPrice[_tokenId] = _price;
    }

    function disallowBuy(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId), 'Not owner of this token');
        tokenIdToPrice[_tokenId] = 0;
    }
    
    function buy(uint256 _tokenId) external payable {
        uint256 price = tokenIdToPrice[_tokenId];
        require(price > 0, 'This token is not for sale');
        require(msg.value == price, string(abi.encodePacked('Incorrect value (value is>',msg.value,')')));
        
        address seller = ownerOf(_tokenId);
        _transfer(seller, msg.sender, _tokenId);
        tokenIdToPrice[_tokenId] = 0; 
        payable(seller).transfer(msg.value); 

        emit NftBought(seller, msg.sender, msg.value);
    }
}