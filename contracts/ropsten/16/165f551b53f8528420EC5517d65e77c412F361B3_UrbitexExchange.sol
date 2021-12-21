// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract UrbitexExchange is Context, Ownable {

    //  azimuth: points state data store
    //
    IAzimuth public azimuth;
    
    // fee: exchange transaction fee 
    // 
    uint32 fee;

    // priceFloor: The minimum price allowed
    // 
    uint256 priceFloor;

    struct ListedAsset {
        address addr;
        uint256 amount;
    }

    // prices: registry which holds the prices set by sellers for their azimuth points in the marketplace
    //
    mapping(uint32 => ListedAsset) assets;

    // EVENTS

    event MarketPurchase(
        address indexed _from,
        address indexed _to,
        uint32 _point,
        uint256 _price
    );

    event ListingRemoved(
        uint32 _point
    );

    event ListingAdded(
        uint32 _point,
        uint256 _price 
    );

    // IMPLEMENTATION

    //  constructor(): configure the points data store, exchange fee, and minimum listing price
    //
    constructor(IAzimuth _azimuth, uint32 _fee, uint256 _priceFloor) 
        payable 
    {     
        require(100000 > _fee, "Input value must be less than 100000");
        azimuth = _azimuth;
        fee = _fee;
        priceFloor = _priceFloor;
    }

    //  purchase(): purchase and transfer azimuth point from the seller to the buyer
    //
    function purchase(uint32 _point)
        external
        payable
    {
        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        
        // get the point's owner 
        address payable seller = payable(azimuth.getOwner(_point));

        // get the asset information from the registry
        ListedAsset memory asset = assets[_point];

        // check that the address in the registry matches the address that currently controls the point
        // 
        require(asset.addr == seller);

        // buyer must pay the exact price as what's stored in the registry for that point
        require(msg.value == asset.amount, "Amount transferred does not match price in registry");

        // the exchange must be an approved transfer proxy for the seller of this point.
        (bool success) = ecliptic.isApprovedForAll(seller, address(this));
        require(success, "The exchange is not authorized as a transfer proxy for this point");

        // when all conditions are met, transfer the point from the seller to the buyer
        ecliptic.transferFrom(seller, _msgSender(), _point); 

        // set the price of the point in the registry to 0 and clear the associated address
        asset = ListedAsset({
             addr: address(0),
             amount: 0
          });

        assets[_point] = asset;

        // deduct exchange fee and transfer remaining amount to the seller
        seller.transfer(msg.value/100000*(100000-fee));    

        emit MarketPurchase(seller, _msgSender(), _point, msg.value);
    }

    // addListing(): add a point and its corresponding price to the registry
    //
    function addListing(uint32 _point, uint256 _price) external returns(bool success)
    {
        // using canTransfer() here instead of isOwner(), since the owner can authorize a third-party
        // operator to transfer.
        // 
        require(azimuth.canTransfer(_point, _msgSender()), "The message sender is not the point owner or an authorized proxy address");
        
        // listed price must be greater than the minimum price set by the exchange
        require(priceFloor < _price, "The listed price must exceed the minimum price set by the exchange");

        // set the price of the point, add it to the prices registry 
        
        ListedAsset memory asset = assets[_point];

        asset = ListedAsset({
             addr: _msgSender(),
             amount: _price
          });

        assets[_point] = asset;

        return true;
    }
    
    // PUBLIC OPERATIONS

    // getListedPrice(): check the listed price of an azimuth point 
    // 
    function getListedPrice(uint32 _point) external view returns (address, uint256) {
        return (assets[_point].addr, assets[_point].amount);
    }

    // getFee(): check the current exchange fee
    // 
    function getFee() external view returns (uint256) {
        return fee;  
    }

    // EXCHANGE OWNER OPERATIONS

    // removeListing(): this function is available to the exchange owner to manually remove a listed price, if ever needed.
    //
    function removeListing(uint32 _point) external onlyOwner {                        
                
        ListedAsset memory asset = assets[_point];

        asset = ListedAsset({
             addr: address(0),
             amount: 0
          });

        assets[_point] = asset;
    }

    function changeFee(uint32 _fee) external onlyOwner  {
        require(100000 > _fee, "Input value must be less than 100000");
        fee = _fee;
    }

    function changePriceFloor(uint256 _priceFloor) external onlyOwner  {
        require(0 < _priceFloor, "Price floor must be greater than 0");
        priceFloor = _priceFloor;
    }
             
    function withdraw(address payable _target) external onlyOwner  {
        require(address(0) != _target);
        _target.transfer(address(this).balance);
    }

    function close(address payable _target) external onlyOwner  {
        require(address(0) != _target);
        selfdestruct(_target);
    }
}