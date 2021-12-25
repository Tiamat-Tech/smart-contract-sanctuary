// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract UrbitexTest is Context, Ownable {

    //  azimuth: points state data store
    //
    IAzimuth public azimuth;
    
    // fee: exchange transaction fee 
    // 
    uint32 public fee;

    // ListedAsset: struct which stores the price and seller's address for a point listed in the marketplace
    // 
    struct ListedAsset {
        address addr;
        uint256 price;
        address reservedBuyer;
    }

    // assets: registry which stores the ListedAsset entries
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

    //  constructor(): configure the points data store, exchange fee, and minimum listing price.
    //
    constructor(IAzimuth _azimuth, uint32 _fee) 
        payable 
    {     
        azimuth = _azimuth;
        setFee(_fee);
    }

    // setRegistryEntry(): utility function to add or remove entries in the registry
    function setRegistryEntry(uint32 _point, address _address, uint256 _price, address _reservedBuyer) internal
    {
        ListedAsset memory asset = assets[_point];

        asset = ListedAsset({
             addr: _address,
             price: _price,
             reservedBuyer: _reservedBuyer
          });

        assets[_point] = asset;
    }

    //  purchase(): purchase and transfer point from the seller to the buyer
    //
    function purchase(uint32 _point)
        external
        payable
    {
        IEcliptic ecliptic = IEcliptic(azimuth.owner());
        
        // get the point's owner 
        address payable seller = payable(azimuth.getOwner(_point));

        // get the point's information from the registry
        ListedAsset memory asset = assets[_point];

        // if a reserved buyer has been set, check that it matches _msgSender()
        if (asset.reservedBuyer != address(0)) {
            require(asset.reservedBuyer == _msgSender(), "This point has been reserved for a different buyer");
        }
        
        // check that the seller's address in the registry matches the point's current owner
        require(asset.addr == seller, "seller address does not match registry");

        // buyer must pay the exact price as what's stored in the registry for that point
        require(msg.value == asset.price, "Amount transferred does not match price in registry");

        // in order to save on gas fees, a check that the seller has approved the exchange as a 
        // transfer proxy can happen off-chain. 

        // when all conditions are met, transfer the point from the seller to the buyer
        ecliptic.transferFrom(seller, _msgSender(), _point); 

        // set the price of the point in the registry to 0 and clear the associated address.
        // 'asset' already declared in memory so not using the utility function this time
        // 
        asset = ListedAsset({
             addr: address(0),
             price: 0,
             reservedBuyer: address(0)
          });

        assets[_point] = asset;

        // deduct exchange fee and transfer remaining amount to the seller
        seller.transfer(msg.value/1000*(1000-fee));    

        emit MarketPurchase(seller, _msgSender(), _point, msg.value);
    }

    //  safePurchase(): Exactly like the purchase() function except with validation checks
    //
    function safePurchase(uint32 _point, bool _unbooted, uint32 _spawnCount)
        external
        payable
    {

        // make sure the booted status matches the buyer's expectations
        require(_unbooted == (azimuth.getKeyRevisionNumber(_point) == 0));

        // make sure the number of spawned child points matches the buyer's expectations
        require(_spawnCount == azimuth.getSpawnCount(_point));

        // get the current ecliptic contract
        IEcliptic ecliptic = IEcliptic(azimuth.owner());        

        // get the point's owner 
        address payable seller = payable(azimuth.getOwner(_point));

        // get the point's information from the registry
        ListedAsset memory asset = assets[_point];

        // check that the address in the registry matches the point's current owner
        require(asset.addr == seller, "seller address does not match registry");

        // buyer must pay the exact price as what's stored in the registry for that point
        require(msg.value == asset.price, "Amount transferred does not match price in registry");

        // in order to save on gas fees, a check that the seller has approved the exchange as a 
        // transfer proxy can happen off-chain. 

        // when all conditions are met, transfer the point from the seller to the buyer
        ecliptic.transferFrom(seller, _msgSender(), _point); 

        // set the price of the point in the registry to 0 and clear the associated address.
        // 'asset' already declared in memory so not using the utility function this time
        // 
        asset = ListedAsset({
             addr: address(0),
             price: 0,
             reservedBuyer: address(0)
          });

        assets[_point] = asset;

        // deduct exchange fee and transfer remaining amount to the seller
        seller.transfer(msg.value/100000*(100000-fee));    

        emit MarketPurchase(seller, _msgSender(), _point, msg.value);
    }

    // addListing(): add a point to the registry, including its corresponding price and owner address.
    // optional reserved buyer address can be included. 
    //
    function addListing(uint32 _point, uint256 _price, address _reservedBuyer) external
    {
        // intentionally using isOwner() instead of canTransfer(), which excludes third-party proxy addresses.
        // the exchange owner also has no ability to list anyone else's assets, it can strictly only be the point owner.
        // 
        require(azimuth.isOwner(_point, _msgSender()), "The message sender is not the point owner");

        // add the price of the point and the seller address to the registry
        //         
        setRegistryEntry(_point, _msgSender(), _price, _reservedBuyer);        
        
        emit ListingAdded(_point, _price);

    }

    // removeListing(): clear the information for this point in the registry. This function has also been made available
    // to the exchange owner to remove stale listings.
    //
    function removeListing(uint32 _point) external 
    {   
        require(azimuth.isOwner(_point, _msgSender()) || _msgSender() == owner(), "The message sender is not the point owner or the exchange owner");
        
        setRegistryEntry(_point, address(0), 0, address(0));

        emit ListingRemoved(_point);
    }

    // getPointInfo(): check the listed price and seller address of a point 
    // 
    function getPointInfo(uint32 _point) external view returns (address, uint256, address) {
        return (assets[_point].addr, assets[_point].price, assets[_point].reservedBuyer);
    }

    // EXCHANGE OWNER OPERATIONS
     
    // setFee(): the fee calculation is a percentage of the listed price.
    // max fee the owner can set is 2.5%. 
    function setFee(uint32 _fee) public onlyOwner  {
        require(25 >= _fee, "Input value must be less than or equal to 25 (2.5%)");
        fee = _fee;
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