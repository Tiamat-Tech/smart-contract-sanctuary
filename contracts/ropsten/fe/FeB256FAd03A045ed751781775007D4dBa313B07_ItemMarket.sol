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
        string title;
        string url;
        uint item_id;
     }

     mapping (uint => Item) items;

    address MyToken = 0x080ee52e0E065306dF807a1cf632dca9B636B1bf;

    event DepositERC20Token(address , uint256 );

     function depositERC20Token(uint256 amount) public {
            IERC20(MyToken).approve(address(this), amount);
            IERC20(MyToken).transferFrom(_msgSender(), address(this), amount);
            emit DepositERC20Token( _msgSender(), amount);
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