pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage, ERC721Enumerable{

    using Counters for Counters.Counter;
    uint256 public price;
    uint256 public start;
    Counters.Counter private _tokenIds;
    mapping (address => Counters.Counter) addressPurchases;
    error BeforeMintingStarted(uint256 current, uint256 start, string message);
    error InsufficientBalance(uint256 available, uint256 required, string message);
    error TokensPerAddressCapReached(uint256 current, uint256 max, string message);
    event Token(uint256 tokenId);
    
    constructor(uint256 _price, uint256 _start) public ERC721("UniqueAsset", "UNA"){
        price = _price;
        start = _start;
    }

    function mint(address recipient, string memory metadata) payable public returns (uint256){
        if(block.timestamp > start){
            revert BeforeMintingStarted({
                current: block.timestamp,
                start: start,
                message: 'minting has not started yet'
            });
        }
        if(msg.value != price){
            revert InsufficientBalance({
                available: msg.value,
                required: price,
                message: '< price'
            });
        }
        if(addressPurchases[recipient].current() >= 4){
            revert TokensPerAddressCapReached({
                current: addressPurchases[recipient].current(),
                max: 4,
                message: 'maximum 5 nfts per address'
            });
        }
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        addressPurchases[recipient].increment();
        return newItemId;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override (ERC721, ERC721Enumerable){
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override (ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage)returns (string memory){
        return super.tokenURI(tokenId);
    }
    // function tokensByAddress(address owner) public{
    //     uint256 index = balanceOf(owner);
    //     for(uint256 start = 0; start < index; start++){
    //         uint256 tokenId = tokenOfOwnerByIndex(owner, start);
    //         emit Token(tokenId);
    //     }
    // }
}