// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WalkingBetweenWorlds is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // set contract name and ticker.
    constructor() ERC721("WalkingBetweenWorlds", "WBW") {}

    //get the current supply of tokens
    function totalSupply() public view returns (uint256) {
        return _tokenIds.current();
    }
    
    function mintItem(address player, string memory tokenURI)
        public
        payable
        returns (uint256)
    {
        uint256 price = 5 * 10 ** 16;
        require(msg.value >= price, "Value should be over 0.05 ETH");
        payable(owner()).transfer(msg.value);
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }
}