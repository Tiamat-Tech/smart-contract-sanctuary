// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ItemMarket is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply {
    constructor() ERC1155("testurl") {}

    struct Item { 
        uint item_id;
        string title;
        string url;
        uint price;
     }

     mapping (uint => Item) items;

      uint lastItemID;

       function getItem(uint _ItemID) public view returns(uint ,string memory,string memory,uint) {   
        return (
            items[_ItemID].item_id,
            items[_ItemID].title,
            items[_ItemID].url,
            items[_ItemID].price
            );
        }

          function setItem (string calldata  _title,string calldata _url,uint _price)  public onlyOwner {

            uint _ItemID= lastItemID+1;
            lastItemID++;
            items[_ItemID].item_id = _ItemID;
            items[_ItemID].title = _title;
            items[_ItemID].url = _url;
            items[_ItemID].price = _price;
        }


    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}