pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    mapping (address => uint) addressPurchasesCounter;
    uint256 price = 1 ether;
    // 2021-12-5 19:05:00 ( + 1 CET)
    uint256 mintingStarts = 1638731100000;
    
    constructor() public ERC721("UniqueAsset", "UNA"){}

    function mint(address recipient, string memory hash, string memory metadata) payable public returns (uint256){
        // require(msg.value == price)
        require(addressPurchasesCounter[msg.sender] <= 5, 'maximum 5 nfts per address');
        require(block.timestamp < mintingStarts, 'minting has not started yet');
        require(hashes[hash]!=1, "already used hash");
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        addressPurchasesCounter[msg.sender]+=1;
        return newItemId;
    }
}