// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PurchaseNFT is Ownable{
    event Purchase(address indexed by, uint indexed tokenId, Currency indexed currency, uint price);

    uint public priceInTokens;
    uint public priceInETH;
    IERC20 private currencyToken;
    ERC721 private nftToken;
    uint private tokenCounter;

    enum Currency {
        ERC20Tokens, // 0
        ETH // 1
    }

    constructor(uint _priceInTokens, uint _priceInETH, address _currencyTokenAddress, address _nftTokenAddress){
        priceInTokens = _priceInTokens;
        priceInETH = _priceInETH;
        currencyToken = IERC20(_currencyTokenAddress);
        nftToken = ERC721(_nftTokenAddress);
    }

    function makePurchaseUsingTokens(uint tokenId) external{
        uint allowance = currencyToken.allowance(msg.sender, address(this));
        require(allowance >= priceInTokens, "PurchaseNFT: price amount not approved");
        currencyToken.transferFrom(msg.sender, address(this), priceInTokens);
        _transferNFT(tokenId);
        emit Purchase(msg.sender, tokenId, Currency.ERC20Tokens ,priceInTokens);
    }

    function makePurchaseUsingEther(uint tokenId) external payable {
        uint amount = msg.value;
        require(amount >= priceInETH, "PurchaseNFT: not enough Ether");
        _transferNFT(tokenId);
        uint refund = amount - priceInETH;
        if(refund > 0){
            payable(msg.sender).transfer(refund);
        }
        emit Purchase(msg.sender, tokenId, Currency.ETH ,priceInETH);
    }

    function _transferNFT(uint tokenId) internal{
        nftToken.safeMint(msg.sender, tokenId);
    }

    function setPriceInTokens(uint _price) external onlyOwner {
        require(_price > 0,"PurchaseNFT: price less than 0");
        priceInTokens = _price;
    }

    function setPriceInETH(uint _price) external onlyOwner {
        require(_price > 0,"PurchaseNFT: price less than 0");
        priceInETH = _price;
    }
}