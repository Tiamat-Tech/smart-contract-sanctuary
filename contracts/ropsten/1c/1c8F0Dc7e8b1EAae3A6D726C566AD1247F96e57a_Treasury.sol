pragma solidity ^0.8.0;

import './interfaces/ISingleNFT.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Treasury {

    using SafeMath for uint256;

    mapping(uint256 => uint256) price;

    ISingleNFT single;

    constructor(address _singleNFT) {
        single = ISingleNFT(_singleNFT);
    }

    function setOnSale(uint256 tokenId, uint256 _price) external {
        require(single.ownerOf(tokenId) == msg.sender, 'Treasury: not owner');
        require(single.isApprovedForAll(msg.sender, address(this)) == true, 'Treasury: not operator');

        price[tokenId] = _price;
        single.setTokenOnSale(tokenId);
    }

    function buyToken(uint256 tokenId) external payable{
        require(single.ownerOf(tokenId) != msg.sender, 'Treasury: not owner');
        require(single.isApprovedForAll(single.ownerOf(tokenId), address(this)) == true, 'Treasury: not operator');
        require(msg.value >= price[tokenId], "Treasury: insufficient funds");

        address payable currentOwner = payable(single.ownerOf(tokenId));
        currentOwner.transfer(msg.value);

        single.setTokenOnBasic(tokenId);
        single.safeTransferFrom(currentOwner, msg.sender, tokenId);
    }

    function cancelOnSale(uint256 tokenId) external {
        require(single.ownerOf(tokenId) == msg.sender, 'Treasury: not owner');
        require(single.isApprovedForAll(msg.sender, address(this)) == true, 'Treasury: not operator');

        single.cancelTokenSale(tokenId);
    }

}