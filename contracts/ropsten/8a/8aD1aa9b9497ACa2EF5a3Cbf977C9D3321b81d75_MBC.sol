//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MBC is ERC1155 {
   
   uint256 tokenId = 100000;
    address public owner; 

    mapping(uint256=>NFT) public NFTData;

    struct NFT{
        address owner;
        address creator;
        uint256 tokenId;
        uint256 currentValue;
        string ccid;
    }

    constructor(string memory _url) ERC1155(_url) {
        owner = _msgSender();
    }

   function mint(
        uint256 _amount,string memory _ccid) public {
            _mint(_msgSender(),tokenId,_amount,"");
            saveNFTData(_msgSender(),_msgSender(), tokenId, _amount , _ccid);
            tokenId++;
    }

    function saveNFTData(address _sender,address _owner,uint256 _tokenId,uint256 tokenValue, string memory _ccid) private {
            NFT storage nft = NFTData[_tokenId];
            require(nft.creator==address(0),"TokenID is already Taken");
            nft.creator = _sender;
            nft.owner = _owner;
            nft.tokenId = _tokenId;
            nft.currentValue = tokenValue;
            nft.ccid = _ccid;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) public {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, "");
    }

}