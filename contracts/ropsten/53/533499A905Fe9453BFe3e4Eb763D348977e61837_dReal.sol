// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract dReal is Ownable {
    IERC20 token;
    
    event NewOffer(address indexed landlord, uint256 price, uint256 collateral, uint256 repetitions, uint256 id);
    event OfferAccepted(uint256 indexed id, address indexed tenant);
    event RentPaid(uint256 id);
    event CollateralClaimed(uint256 id);
    event PaymentClaimed(uint256 id, uint256 totalClaimed);
    
    struct Offer {
        bool valid;
        uint256 startDate;
        address tenant;
        address landlord;
        uint256 price;
        uint256 collateral;
        uint256 repetitions;
        string street;
        string description;
        bool accepted;
        uint256 timesPaid;
        bool collateralClaimed;
    }
    
    mapping(address => uint256[]) landlordOffers;
    mapping(address => uint256[]) tenantOffers;
    mapping(uint256 => Offer) public offers;
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    function getTotalOffersByLandlord(address _landlord) public view returns(uint256) {
        return landlordOffers[_landlord].length;
    }
    
    function getTotalOffersByTenant(address _tenant) public view returns(uint256) {
        return tenantOffers[_tenant].length;
    }
    
    function getLandlordOfferByIndex(address _landlord, uint256 _position) public view returns(uint256) {
         return landlordOffers[_landlord][_position];
    }

    function getTenantOfferByIndex(address _tenant, uint256 _position) public view returns(uint256) {
         return tenantOffers[_tenant][_position];
    }
    
    function _TEST_updateStartDate(uint256 _id, uint256 _startDate) public onlyOwner {
        offers[_id].startDate = _startDate;
    }
    
    function createRent(uint256 _price, uint256 _collateral, uint256 _repetitions, string memory _street, string memory _description) public {
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp)));
        require(!offers[id].valid, "The offer already exists");
        require(_price > 0, "Invalid price");
        require(_repetitions > 0, "Invalid repetitions");
        
        Offer memory o;
        o.valid = true;
        o.landlord = msg.sender;
        o.price = _price;
        o.collateral = _collateral;
        o.repetitions = _repetitions;
        o.street = _street;
        o.description = _description;
        
        offers[id] = o;
        landlordOffers[msg.sender].push(id);
        
        emit NewOffer(msg.sender, _price, _collateral, _repetitions, id);
    }

    function acceptRent(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.landlord != msg.sender, "Landlord cannot accept self offer");
        require(!offer.accepted, "Already accepted");
        
        require(token.transferFrom(msg.sender, address(this), offer.collateral + offer.price), 'Could not transfer tokens');

        offer.accepted = true;
        offer.tenant = msg.sender;
        offer.startDate = block.timestamp;
        offer.timesPaid = 1;

        tenantOffers[msg.sender].push(_id);

        emit OfferAccepted(_id, msg.sender);
        emit RentPaid(_id);
    }
    
    function payRent(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.tenant == msg.sender, "Invalid caller");
        require(offer.repetitions > offer.timesPaid, "Already paid it all");
        
        require(token.transferFrom(msg.sender, address(this), offer.price), 'Could not transfer tokens');

        offer.timesPaid += 1;
        
        emit RentPaid(_id);
    }
    
    function claimCollateral(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.accepted, "Invalid offer");
        require(offer.tenant == msg.sender, "Invalid caller");
        require(offer.repetitions == offer.timesPaid, "Not yet totally paid");
        require(!offer.collateralClaimed, "Already claimed");
        
        offer.collateralClaimed = true;

        require(token.transfer(msg.sender, offer.collateral), 'Could not transfer tokens');
        
        emit CollateralClaimed(_id);
    }
    
    function calculatePaymentsToClaim(uint256 _startDate, uint256 _timesPaid, uint256 _repetitions) public view returns(uint256) {
        if (_timesPaid >= _repetitions) {
            return 0;
        }

        uint256 timePassed = block.timestamp - _startDate;
        uint256 monthsPassed = timePassed / 30 days;
        uint256 expectedTimesPaid = monthsPassed + 1;
        
        if (expectedTimesPaid > _repetitions) {
            expectedTimesPaid = _repetitions;
        }
        
        return expectedTimesPaid - _timesPaid;
    }
    
    function claimPayment(uint256 _id) public {
        require(offers[_id].valid, "Invalid offer");
        Offer storage offer = offers[_id];
        require(offer.accepted, "Invalid offer");
        require(offer.landlord == msg.sender, "Invalid caller");
        
        uint256 paymentsToClaim = calculatePaymentsToClaim(offer.startDate, offer.timesPaid, offer.repetitions);
        
        uint256 totalToClaim = paymentsToClaim * offer.price;
        
        if (totalToClaim > offer.collateral) {
            totalToClaim = offer.collateral;
        }
        
        require(totalToClaim > 0, "Not enough collateral");
        
        offer.collateral -= totalToClaim;
        offer.timesPaid += paymentsToClaim;
     
        require(token.transfer(msg.sender, totalToClaim), 'Could not transfer tokens');
        
        emit PaymentClaimed(_id, totalToClaim);
    }
}