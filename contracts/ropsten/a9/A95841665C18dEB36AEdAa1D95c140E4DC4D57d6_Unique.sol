pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Unique is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(string => uint8) hashes;
    
    constructor() public ERC721("UniqueAsset", "UNA"){}

    function mint(address recipient, string memory hash, string memory metadata) payable public returns (uint256){
        // require(msg.value == uint256 expectedAmount), expectedAmount should be argument in `mint`
        // require(msg.value > 0);
        require(hashes[hash]!=1, "already used hash");
        hashes[hash] = 1;
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        return newItemId;
    }
}