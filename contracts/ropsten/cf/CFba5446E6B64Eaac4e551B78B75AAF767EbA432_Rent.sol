// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Rent is Ownable {
    IERC20 token = IERC20(0x1d9631569330dEd7340140F2b8Fc3918C13d7041);
    
    uint256 collateral = 10 * 10 ** 18;

    event NewOffer(address indexed landlord, address indexed tenant, uint256 price, uint256 repetitions);
    event OfferAccepted(uint256 id);
    event RentPaid(uint256 id);
    
    struct Offer {
        bool valid;
        uint256 startDate;
        address tenant;
        address landlord;
        uint256 price;
        uint256 repetitions;
        bool accepted;
        uint256 timesPaid;
    }
    
    mapping(uint256 => Offer) offers;
    mapping(address => uint256[]) landlordOffers;
    mapping(address => uint256[]) tenantOffers;

    function createRent(address _tenant, uint256 _price, uint256 _repetitions) public {
        require(_tenant != address(0), "Invalid tenant");
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender, _tenant)));
        require(!offers[id].valid, "The offer already exists");
        require(_price > 0, "Invalid price");
        require(_repetitions > 0, "Invalid repetitions");
        
        Offer memory o;
        o.valid = true;
        o.landlord = msg.sender;
        o.tenant = _tenant;
        o.price = _price;
        o.repetitions = _repetitions;
        
        offers[id] = o;
        landlordOffers[msg.sender].push(id);
        tenantOffers[_tenant].push(id);
        
        emit NewOffer(msg.sender, _tenant, _price, _repetitions);
    }

    function acceptRent(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.tenant == msg.sender, "Invalid caller");
        
        require(token.transfer(msg.sender, collateral), 'Could not transfer tokens');

        offer.accepted = true;
        offer.startDate = block.timestamp;

        emit OfferAccepted(_id);
    }
    
    function payRent(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.tenant == msg.sender, "Invalid caller");
        
        require(token.transfer(msg.sender, offer.price), 'Could not transfer tokens');

        offer.timesPaid += 1;
        
        emit RentPaid(_id);
    }
}