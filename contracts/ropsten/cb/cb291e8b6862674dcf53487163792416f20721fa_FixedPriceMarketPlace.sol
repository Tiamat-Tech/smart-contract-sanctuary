// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import '@openzeppelin/contracts/utils/Counters.sol';
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import './FixedPriceMarketPlaceStorage.sol';




contract FixedPriceMarketPlace is Initializable,
                                  OwnableUpgradeable,
                                  UUPSUpgradeable,PausableUpgradeable,ReentrancyGuardUpgradeable,FixedPriceMarketPlaceStorage {

    using Counters for Counters.Counter;


    // +Error
    error InvalidPrice(uint256 invalidPrice) ;
    error InvalidMarketItem(uint256 itemId) ;
    error OnlySeller(address seller,address sender) ;
    error SoldItem(uint256 itemId) ;
    error OnlyOwner(address seller,address sender) ;
    error OwnedToken(address seller) ;
    // -Error

    // +EVENTS --------------------------------------------------
    event MarketItemDeleted(uint indexed itemId, uint256 tokenId);
    event MoneyTransferred(address from, address to, uint256 amount);
    event NFTTransferred(address from, address to, uint256 tokenId);
    event MarketItemCreated(
        uint indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        uint256 timestamp
        );
    event MarketItemSold(
        uint indexed itemId,
        uint256 indexed tokenId,
        address seller,
        address buyer
        );
    event MarketItemPriceChanged(uint256 itemId, uint256 newPrice);

    // -EVENTS --------------------------------------------------

    constructor() {}

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }
    

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function initToken(address _NFTationContract,uint8 marketPlaceSharePercentage) public onlyOwner {
        NFTationContract = NFTation(_NFTationContract);
        marketPlaceShare = marketPlaceSharePercentage;
    }

    function changeMarketPlaceShare(uint8 _marketPlaceShare) external onlyOwner{
        marketPlaceShare = _marketPlaceShare;
    }

    function getMarketShareAndRoyalty(uint256 tokenId,uint256 price) private view 
    returns(uint256 marketShareAmount,uint256 royaltyAmount ,address  creator){
        bool isFirstSale = NFTationContract.checkFirstSale(tokenId);
        if(isFirstSale){
            marketShareAmount = (price *(marketPlaceShare+ (NFTationContract.getRoyaltyPercentage(tokenId))))/100;
            return (marketShareAmount, 0,address (0));
        }
        else{
             marketShareAmount = ((marketPlaceShare *price) /100);
            (creator, royaltyAmount) = NFTationContract.royaltyInfo(tokenId ,price);
            return (marketShareAmount, royaltyAmount,creator);
        }
    }

    function getMarketItemPrice(uint256 _marketItemId) public view returns(uint256) {
        return idToMarketItem[_marketItemId].price;
    }

    function createMarketItem(uint256 tokenId, uint256 price) public payable whenNotPaused nonReentrant returns (uint256)   {
        if(price <= 0)
            revert InvalidPrice({  invalidPrice:price  });
        _itemIds.increment();
        uint itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            itemId,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            false,
            true);

        //external call
        NFTationContract.transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(itemId, tokenId, msg.sender, address(this), price, block.timestamp);
        return itemId;
    }

    function changeMarketItemPrice(uint256 _itemId, uint256 _newPrice) public whenNotPaused  {
        MarketItem storage _marketItem = idToMarketItem[_itemId];
        if(!_marketItem.isActive)
            revert   InvalidMarketItem(_itemId);
        if(msg.sender != _marketItem.seller)
            revert OnlySeller(_marketItem.seller,msg.sender);
        _marketItem.price = _newPrice;

        emit MarketItemPriceChanged(_itemId, _newPrice);
    }

    function deleteMarketItem(uint256 _itemId) public whenNotPaused nonReentrant {
        MarketItem storage _marketItem = idToMarketItem[_itemId];
        if(_marketItem.sold == true)    
            revert SoldItem( _itemId);
        if(msg.sender != _marketItem.seller)
            revert OnlyOwner( _marketItem.seller, msg.sender );
        //external call
        NFTationContract.transferFrom(address(this), _marketItem.seller, idToMarketItem[_itemId].tokenId);

        delete idToMarketItem[_itemId];
        emit MarketItemDeleted(_itemId, idToMarketItem[_itemId].tokenId);
    }

    function createMarketSale(uint256 itemId) public payable whenNotPaused nonReentrant {
        MarketItem storage marketItem = idToMarketItem[itemId];

        uint price = marketItem.price;
        uint _tokenId = marketItem.tokenId;

        if(msg.value != price)
            revert InvalidPrice( price);
        if(msg.sender == marketItem.seller)
            revert OwnedToken(marketItem.seller);

        (uint256 marketPlaceShareAmount, uint256 royaltyAmount,address  tokenCreator) = getMarketShareAndRoyalty(_tokenId, price);
        
        marketItem.owner = payable(msg.sender);
        marketItem.sold = true;
        marketItem.isActive = false;
        _itemsSold.increment();

        //External call

        //payable(owner()).transfer(marketPlaceShareAmount);
         bool sent;
        (sent, ) = payable(owner()).call{value: marketPlaceShareAmount}("") ;
        require(sent);
        
        if(royaltyAmount > 0){
            (sent, ) = payable(tokenCreator).call{value: royaltyAmount}("") ;
            require(sent);
            //payable(tokenCreator).transfer(royaltyAmount);
        }
        if(NFTationContract.checkFirstSale(_tokenId)){
            NFTationContract.disableFirstSale(_tokenId);
        }
        uint256 remaining = (price-(marketPlaceShareAmount))-(royaltyAmount);

        //marketItem.seller.transfer(remaining);
        (sent, ) = payable(marketItem.seller).call{value: remaining}("");
        require(sent);
        
        NFTationContract.transferFrom(address(this), msg.sender, _tokenId);

        emit MoneyTransferred(msg.sender, marketItem.seller, remaining);
        emit NFTTransferred(address(this), msg.sender, _tokenId);
        emit MarketItemSold(itemId, _tokenId, marketItem.seller, msg.sender);
    }
}