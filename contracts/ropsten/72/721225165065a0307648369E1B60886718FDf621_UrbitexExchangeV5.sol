// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./interface/IAzimuth.sol";
import "./interface/IEcliptic.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";


contract UrbitexExchangeV5 is Context, Ownable {

    //  azimuth: points state data store
    //
    IAzimuth public azimuth;
    
    // fee: exchange transaction fee 
    // 
    uint256 fee;

    // prices: registry which holds the prices set by sellers for their azimuth points in the marketplace
    //
    mapping(uint32 => uint256) prices;

    // EVENTS

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _point,
        uint256 _price
    );

    // IMPLEMENTATION

    //  constructor(): configure the points data store and exchange fee
    //
    constructor(IAzimuth _azimuth, uint256 _fee) 
        payable 
    {     
        require(100000 > _fee, "Input value must be less than 100000");
        azimuth = _azimuth;
        fee = _fee;
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

        // get the price of the point from the registry
        uint256 price = prices[_point];

        // buyer must pay the exact price as what's stored in the registry for that point
        require(msg.value == price, "Amount transferred does not match price in registry");

        // amount cannot be zero.
        require(0 < msg.value, "Amount must be greater than zero");

        // the exchange must be an approved transfer proxy for this point.
        (bool success) = ecliptic.isApprovedForAll(seller, address(this));
        require(success, "The exchange is not authorized as a transfer proxy for this point");

        // when all conditions are met, transfer the point from the seller to the buyer
        ecliptic.transferFrom(seller, _msgSender(), _point); 

        // set the price of the point in the registry to 0
        prices[_point] = 0;

        // deduct exchange fee and transfer remaining amount to the seller
        seller.transfer(msg.value/100000*(100000-fee));    

        emit Transfer(seller, _msgSender(), _point, msg.value);
    }

    // addListing(): add a point and its corresponding price to the registry
    //
    function addListing(uint32 _point, uint256 _price) external returns(bool success)
    {
        // using canTransfer() here instead of isOwner(), since the owner can authorize a third-party
        // operator to transfer.
        // 
        require(azimuth.canTransfer(_point, _msgSender()), "The message sender is not the point owner or an authorized proxy address");
        
        // listed price must be greater than zero
        require(0 < _price, "The listed price must be greater than zero");

        // set the price of the point, add it to the prices registry 
        prices[_point] = _price;

        return true;
    }
    
    // getListedPrice(): check the listed price of an azimuth point 
    // 
    function getListedPrice(uint32 _point) external view returns (uint256){                
        return prices[_point];  
    }

    // EXCHANGE OWNER OPERATIONS

    // removeListing(): this function is available to the exchange owner to manually remove a listed price, if ever needed.
    //
    function removeListing(uint32 _point) external onlyOwner {                        
        prices[_point] = 0;
    }

    function changeFee(uint256 _fee) external onlyOwner  {
        require(100000 > _fee, "Input value must be less than 100000");
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