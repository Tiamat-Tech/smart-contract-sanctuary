pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (address => uint) addressPurchasesCounter;
    uint256 public price;
    uint256 public start;
    
    constructor(uint256 _price, uint256 _start) public ERC721("UniqueAsset", "UNA"){
        price = _price;
        start = _start;
    }

    function mint(address recipient, string memory metadata) payable public returns (uint256){
        require(msg.value == price, '< price');
        require(addressPurchasesCounter[msg.sender] <= 5, 'maximum 5 nfts per address');
        require(block.timestamp > start, 'minting has not started yet');
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        addressPurchasesCounter[msg.sender]+=1;
        return newItemId;
    }
}