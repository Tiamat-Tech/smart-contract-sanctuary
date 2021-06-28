// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Unique is ERC721URIStorageUpgradeable, OwnableUpgradeable, UUPSUpgradeable{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    address payable internal royaltyOwner;
    CountersUpgradeable.Counter internal ids;
    uint256 internal rate;

    enum Stages {
        NotForSale,
        ForSale,
        SaleInProgress
    }
    struct Sale {
        Stages status;
        uint price;
        address buyer;
    }

    mapping(uint256 => Sale) internal auction;

    event RoyaltyRateSet(uint256 rate);
    event RoyaltyOwnerSet(address newOwner);
    event Created(address account, uint256 id);
    event CreatedBatch(address account, uint256[] ids);
    event Deleted(uint256 id);
    event AuctionPrice(uint256 id, uint price);
    event Purchased(uint256 id, address buyer);
    event TransferredBatch(address operator, address from, address to, uint256[] ids);

    function initialize(address payable _royaltyOwner, uint256 _rate) external initializer{
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC721URIStorage_init();
        setRoyaltyOwner(_royaltyOwner);
        setRoyaltyRate(_rate);
    }

    function buyMoment(uint256 id) external virtual payable {
        require(
            msg.value >= auction[id].price,
            "Minimum purchase price not met"
        );
        require(
            auction[id].status == Stages.ForSale,
            "Moment not for sale"
        );

        // mark the NFT no longer for sale once it has a buyer
        auction[id].status = Stages.SaleInProgress;
        auction[id].price = msg.value;
        auction[id].buyer = msg.sender;
        safeTransferFrom(ownerOf(id), msg.sender, id);
        emit Purchased(id, msg.sender);
    }

    function createMoment(
        address account, 
        string memory uri
    ) 
        external virtual 
        onlyOwner 
        returns (uint256 id) 
    {
        uint256 _id = ids.current();
        ids.increment();
        _safeMint(account, _id);
        _setTokenURI(_id, uri);
        emit Created(account, _id);
        return _id;
    }

    function createMoments(
        address account,
        uint256 numberOfMoments,
        string[] memory uri
    ) 
        external virtual 
        onlyOwner 
        returns (uint256[] memory _ids) 
    {
        uint256[] memory _idsArray = new uint256[](numberOfMoments);

        for (uint i = 0; i < numberOfMoments; i++){
            _idsArray[i] = ids.current();
            ids.increment();         
        }
        _mintBatch(account, _idsArray, uri);

        emit CreatedBatch(account, _idsArray);
        return _idsArray;
    }

    function deleteMoment(uint256 id) external virtual {
        require(
            msg.sender == ownerOf(id),
            "Must be owner of Moment to delete Moment"
        );

        _burn(id);
        emit Deleted(id);
    }

    function setPrice(uint256 id,uint price) external virtual {
        require(msg.sender == ownerOf(id));
        require(auction[id].status != Stages.SaleInProgress); 

        if (price == 0) {
            auction[id].status = Stages.NotForSale;
            auction[id].buyer = address(0);
        } else {
            auction[id].status = Stages.ForSale;
        }
        auction[id].price = price;

        emit AuctionPrice(id, price);
    }

    function getPrice(uint256 id) external view virtual returns (uint) {
        return auction[id].price;
    }

    function getSaleStatus(uint256 id) external view virtual returns (Stages) {
        return auction[id].status;
    }
    
    function getRoyaltyOwner() external view virtual returns (address) {
        return royaltyOwner;
    }

    function getRoyaltyRate() external view virtual returns (uint256) {
        return rate;
    }

    function getCurrentId() external view virtual returns (uint256){
        return ids.current() - 1;
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }   

    function setRoyaltyOwner(address payable newOwner) public virtual onlyOwner {
        require(newOwner != address(0));
        royaltyOwner = newOwner;
        emit RoyaltyOwnerSet(royaltyOwner);
    }

    function setRoyaltyRate(uint256 _rate) public virtual onlyOwner {
        rate = _rate;
        emit RoyaltyRateSet(rate);
    } 
    
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 id
    ) 
        internal virtual override 
    {
        if(from != address(0) && to != address(0)) {
            require(auction[id].buyer == to); 
            require(auction[id].status == Stages.SaleInProgress); 

            // reset auction sale so NFT is no longer for sale
            auction[id].status = Stages.NotForSale;
            auction[id].buyer = address(0);
            uint256 price = auction[id].price;
            auction[id].price = 0;
            // calculate royalty fee
            uint256 fee = (price * rate) / 100;
            // transfer fee to royalty address
            royaltyOwner.transfer(fee);
            // transfer funds minus fee to seller
            payable(ownerOf(id)).transfer(price - fee);
        }
    }
    
    function _mintBatch(   
        address account, 
        uint256[] memory _ids, 
        string[] memory uri
    ) 
        internal virtual 
        onlyOwner 
    {
        require(account != address(0));
        require(_ids.length == uri.length);

        address operator = _msgSender();

        for (uint i = 0; i < _ids.length; i++) {
               _safeMint(account, _ids[i]);
               _setTokenURI(_ids[i], uri[i]);        
        }

        emit TransferredBatch(operator, address(0), account, _ids);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}   
}