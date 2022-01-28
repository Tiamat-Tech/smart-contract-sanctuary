//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC721URIStorage.sol";
import "./Counters.sol";
import "./Ownable.sol";


contract MPIslands is ERC721URIStorage , Ownable {
    struct NFT_Info{
        string NFT_Name;
        string Grade_Level;
        string Main_Category;
        uint256 Price;
    }
    mapping(uint256 => NFT_Info) private MP_items;
    event ItemAdded(address indexed recipient, uint256 indexed newItemId);
    event Minted(string indexed str);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("MPIslands", "NFT") {}

    function mintIsland(address recipient, string memory NFT_Name, string memory Grade_Level, uint256 Price)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        //_setTokenURI(newItemId, NFT_Name);

        require(_exists(newItemId), "ERC721URIStorage: URI set of nonexistent token");
        MP_items[newItemId].NFT_Name = NFT_Name;
        MP_items[newItemId].Grade_Level = Grade_Level;
        MP_items[newItemId].Main_Category = "Island";
        MP_items[newItemId].Price = Price;        
        emit ItemAdded(recipient, newItemId);
        return newItemId;
    }


    function getItem(uint256 id) public view returns(NFT_Info memory) {
      return MP_items[id];
    }

}