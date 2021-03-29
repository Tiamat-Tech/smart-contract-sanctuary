//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 private _mintNFTPrice;
    bool private _startSale;
    mapping(uint256 => uint256) private _price;
    mapping(uint256 => bool) private _purchaseAllowed;

    constructor() public ERC721("MyNFT", "NFT") {}

// receipient will be _msgSender()
// onlyOwner will be removed
// payable with fixed price

    function setNFTPrice( uint256 amount)
        public onlyOwner
        returns (bool)
    {
        _mintNFTPrice = amount;
        return true;
    }

    function startSale()
        public onlyOwner
        returns (bool)
    {
     
        _startSale = true;
        return true;

    }
    function mintNFT( string memory tokenURI)
        public payable 
        returns (uint256)
    {
        require(_mintNFTPrice == msg.value, " Purchase amount not matched! ");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(_msgSender(), newItemId);
        _setTokenURI(newItemId, tokenURI);

         address(uint160((owner()))).transfer(msg.value);

        return newItemId;
    }


    function buyNFT(uint256 tokenId)
        public payable
        returns (bool)
    {
        require(_purchaseAllowed[tokenId],"Token is not open for purchase!");
        require(_price[tokenId] == msg.value,"Purchase amount not matched!");

        _transfer(ownerOf( tokenId), _msgSender(), tokenId);
        _purchaseAllowed[tokenId] = false;
        address(uint160(ownerOf( tokenId))).transfer(((msg.value * 90) /100));
        address(uint160(owner())).transfer(((msg.value)*(10))/(100));
   

        return true;
    }

    function setTokenPrice(uint256 tokenId , uint256 amount)
        public 
        returns (bool)
    {
        require(_msgSender() == ownerOf( tokenId),"Token doesn't belongs to the sender");
        _price[tokenId] = amount;
      
        

        return true;
    }


     function allowPurchase(uint256 tokenId, bool allow)
        public 
        returns (bool)
    {
        require(_msgSender() == ownerOf( tokenId),"Token doesn't belongs to the sender");
        _purchaseAllowed[tokenId] = allow;
        return true;
    }
    function parseAddr(string memory _a) internal pure returns (address) {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;
    for (uint i = 2; i < 2 + 2 * 20; i += 2) {
        iaddr *= 256;
        b1 = uint160(uint8(tmp[i]));
        b2 = uint160(uint8(tmp[i + 1]));
        if ((b1 >= 97) && (b1 <= 102)) {
            b1 -= 87;
        } else if ((b1 >= 65) && (b1 <= 70)) {
            b1 -= 55;
        } else if ((b1 >= 48) && (b1 <= 57)) {
            b1 -= 48;
        }
        if ((b2 >= 97) && (b2 <= 102)) {
            b2 -= 87;
        } else if ((b2 >= 65) && (b2 <= 70)) {
            b2 -= 55;
        } else if ((b2 >= 48) && (b2 <= 57)) {
            b2 -= 48;
        }
        iaddr += (b1 * 16 + b2);
    }
    return address(iaddr);
}

}