// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract APATHYV2 is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("APATHYV2", "MEH"){}

    function mint(address recipient) public payable returns (uint256){
        require(msg.value >= 0.1 ether, "Wrong Amount");
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        
        _setTokenURI(newItemId,string(abi.encodePacked("https://gateway.pinata.cloud/ipfs/QmV8XuR4PDvaqd8LErch5ZCEZkfNaozp2eocXgMYDvBzDG/", Strings.toString(newItemId))));

        return newItemId;
        
    }
}