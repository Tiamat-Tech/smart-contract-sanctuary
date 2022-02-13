// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


/**
 * @title Sales
 * Sales - a sales contract for Arcade ERC721 Tokens
 */
contract Sales is Ownable, Pausable {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Received(address indexed payer, uint tokenId, uint256 amount, uint256 balance);

    ERC721 public nftAddress;
    uint256 public currentPrice;

    /**
     * @dev Contract Constructor
     * @param _nftAddress address for Crypto Arte non-fungible token contract 
     * @param _currentPrice initial sales price
     */
    constructor(address _nftAddress, uint256 _currentPrice) { 
        require(_nftAddress != address(0) && _nftAddress != address(this));
        require(_currentPrice > 0);
        nftAddress = ERC721(_nftAddress);
        currentPrice = _currentPrice;
    }

    /**
     * @dev Purchase _tokenId
     * @param _tokenId uint256 token ID
     */
    function purchaseToken(uint256 _tokenId) public payable whenNotPaused {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(msg.value >= currentPrice);
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        nftAddress.safeTransferFrom(tokenSeller, msg.sender, _tokenId);
        emit Received(msg.sender, _tokenId, msg.value, address(this).balance);
    }

    /**
     * @dev send / withdraw _amount to _payee
     * @param _payee address withdraw to address
     * @param _amount uint256 amount to withdraw
     */
    function sendTo(address _payee, uint256 _amount) public payable onlyOwner {
        require(_payee != address(0) && _payee != address(this));
        require(_amount > 0 && _amount <= address(this).balance);
        payable(_payee).transfer(_amount);
        emit Sent(_payee, _amount, address(this).balance);
    }    

    /**
     * @dev Update _currentPrice price of token
     */
    function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
        require(_currentPrice > 0);
        currentPrice = _currentPrice;
    }        

}