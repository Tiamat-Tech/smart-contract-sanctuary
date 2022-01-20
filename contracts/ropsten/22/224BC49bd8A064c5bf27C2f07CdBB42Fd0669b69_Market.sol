pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol'; 

contract Market {

    address public admin;
    address public NFTContractAddress;

    uint public offerID = 1;  
    uint public basePrice = 1000;

    struct Offer {
        uint tokenID;
        address payable tokenOwner;
        uint sellPrice;
    }

    mapping(uint => Offer) public offer;

    constructor(address _NFTAddress) {
        NFTContractAddress = _NFTAddress;
        admin = msg.sender;
    } 
    
    modifier onlyOwner() {
        require(admin == msg.sender, "You're are not the owner");
        _;
    }

    event itemBought(uint offerID, address buyer, uint price); 
    event listingCancelled(uint offerID, address tokenOwner);
    event newListing(uint offerID, address seller, uint price);

    function listItems(uint _tokenID, uint _listingPrice) external { 
        require(IERC721(NFTContractAddress).ownerOf(_tokenID) == msg.sender, "You're not the owner");
        require(_listingPrice > basePrice, 'You need to pay more than the base price');
        IERC721(NFTContractAddress).transferFrom(msg.sender, address(this), _tokenID);
        offer[offerID] = Offer(_tokenID, payable(msg.sender), _listingPrice);
        emit newListing(offerID, msg.sender, _listingPrice);
        offerID++;
    }

    function cancelListing(uint _offerID) internal { 
        Offer memory _offer = offer[_offerID];
        require(_offer.tokenOwner == msg.sender);
        IERC721(NFTContractAddress).transferFrom(address(this), msg.sender, _offer.tokenID);
        emit listingCancelled(_offerID, _offer.tokenOwner);
        delete offer[_offerID];
    }
    function buyItem(uint _offerID) external payable { 
        Offer memory _offer = offer[_offerID];
        require(_offer.sellPrice <= msg.value, "You're not paying enough");
        IERC721(NFTContractAddress).transferFrom(address(this), msg.sender, _offer.tokenID);
        address payable Towner = _offer.tokenOwner;
        Towner.transfer(msg.value);
        emit itemBought (_offerID, msg.sender, msg.value);
        delete offer[_offerID];
    }
}