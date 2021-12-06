pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping (address => Counters.Counter) addressPurchases;
    uint256 public price;
    uint256 public start;
    error InsufficientBalance(uint256 available, uint256 required, string message);
    error BeforeMintingStarted(uint256 current, uint256 start, string message);
    error TokensPerAddressCapReached(uint256 current, uint256 max, string message);
    
    constructor(uint256 _price, uint256 _start) public ERC721("UniqueAsset", "UNA"){
        price = _price;
        start = _start;
    }

    function mint(address recipient, string memory metadata) payable public returns (uint256){
        if(msg.value != price){
            revert InsufficientBalance({
                available: msg.value,
                required: price,
                message: '< price'
            });
        }
        if(addressPurchases[recipient].current() <= 4){
            revert TokensPerAddressCapReached({
                current: addressPurchases[recipient].current(),
                max: 4,
                message: 'maximum 5 nfts per address'
            });
        }
        if(block.timestamp > start){
            revert BeforeMintingStarted({
                current: block.timestamp,
                start: start,
                message: 'minting has not started yet'
            });
        }
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        addressPurchases[recipient].increment();
        return newItemId;
    }
}