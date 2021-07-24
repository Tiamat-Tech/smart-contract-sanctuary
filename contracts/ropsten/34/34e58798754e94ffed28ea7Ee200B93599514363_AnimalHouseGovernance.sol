// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./AbstractAnimalHouseEntity.sol";
import "./CreatorCollection.sol";

import "hardhat/console.sol";


/**
 * This is the implementation of the AnimalHouse network governance contract.
 * It provides values that are relevant in the whole network like conversion rate from AnimalHouse coins to 
 * social tokens. 
 * Futhermore it is the single gate for creators to join the AnimalHouse network by creating a AnimalHouse creators collection
 * through it. Therefore it also maintains some metadata regarding creators.
 *
 */
contract AnimalHouseGovernance is AbstractAnimalHouseEntity {


    /* network global values */
    uint256 private _socialTokenConversionRate = 1;         // conversion rate between coins and social tokens
    uint256 private _creatorCollectionPrice = 10 ether;     // price for a AnimalHouse collection contract
    uint256 private _initialNftPrice = 1 ether;             // initial price for NFT auction from creator
    uint256 private _nftAuctionTokenTreshold = 1 ether;     /* amount of social tokens an address needs to own 
                                                               to be able to bid for content of the corresponding
                                                               creator */
    uint256 private _nftAuctionStepMultiplier = 2 ether;    // multiplier to overbid the current maximum bid for an NFT
    uint256 private _nftAuctionFee = 0.05 ether;            // multiplier that is used for the platform fee of the highest bidder
    uint256 private _nftAuctionDuration = 2 days;           // auction time for NFT once the first bid has been placed

    /* creators collection metadata */
    uint256 private _creatorCount = 0;
    mapping(address => address) private _ownerToCollection;
    mapping(address => bool) private _collectionToValid; // mapping to check if a collection is a known AnimalHouse collection

    /* events */
    event NewCollection(address owner, address collection);

    /* functions */

    constructor (address adminAddr, address walletAddr){
        require(adminAddr != owner(), "AnimalHouse Governance: Owner and admin cannot be the same address.");
        _admin = adminAddr;
        _walletPayable = payable(walletAddr);
    }

    /* In case of fallback or receive the contract only accepts coins from known AnimalHouse collection. */
    fallback() external payable {
        require(_collectionToValid[_msgSender()], "AnimalHouse Governance: Only AnimalHouse collection can send coins directly.");
    }
    receive() external payable {
        require(_collectionToValid[_msgSender()], "AnimalHouse Governance: Only AnimalHouse collection can send coins directly.");
    }

    /**
     * Create a new creators collection contract and assign it to the sender as the new owner.
     * The function must be called alonside the payment for the contract that is specified by the 
     * gobal variable 'creatorCollectionPrice'.
     * Furthermore some central metadata will be maintained.
     */
    function createCollection() public payable nonReentrant returns (bool) {

        require(_ownerToCollection[_msgSender()] == address(0), "AnimalHouse Governance: Sender is already assigned to a collection.");
        require(msg.value >= _creatorCollectionPrice, "AnimalHouse Governance: Insufficient funds for collection creation.");

        CreatorCollection collection = new CreatorCollection(_msgSender());
        _creatorCount = _creatorCount + 1;

        _ownerToCollection[_msgSender()] = address(collection);
        _collectionToValid[address(collection)] = true;

        emit NewCollection(_msgSender(), address(collection));

        address payable senderPayable = payable(_msgSender());
        senderPayable.transfer(msg.value - _creatorCollectionPrice);

        return true;
    }

    function payFee() external payable {
        require(_collectionToValid[_msgSender()], "AnimalHouse Governance: Only AnimalHouse collection can send coins directly.");
    }

    /***************************************************
     * Network Global Values Getters & Setters
     ***************************************************/

    /** 
     * getter & setter for the network wide conversion rate from AnimalHouse coins to social tokens
     * that is used to purchase social tokens directly from the creator
     */
    function socialTokenConversionRate() public view returns (uint256){
        return _socialTokenConversionRate;
    }
    function setSocialTokenConversionRate(uint256 newRate) external onlyOwnerOrAdmin {
        _socialTokenConversionRate = newRate;
    }

    /* getter & setter for the price a creator has to pay in order to create a collection contract */
    function creatorCollectionPrice() public view returns (uint256){
        return _creatorCollectionPrice;
    }
    function setCreatorCollectionPrice(uint256 newPrice) external onlyOwnerOrAdmin {
        _creatorCollectionPrice = newPrice;
    }

    /* getter & setter for the initial price every NFT will have as starting price for the creation bidding */
    function initialNftPrice() public view returns (uint256){
        return _initialNftPrice;
    }
    function setInitialNftPrice(uint256 newPrice) external onlyOwnerOrAdmin {
        _initialNftPrice = newPrice;
    }

    /**
     * getter & setter for the amount of social token of a collection an address needs to own 
     * in order to be able to bid on NFT content of that collection.
     */
    function nftAuctionTokenTreshold() public view returns (uint256){
        return _nftAuctionTokenTreshold;
    }
    function setNftAuctionTokenTreshold(uint256 newTreshold) external onlyOwnerOrAdmin {
        _nftAuctionTokenTreshold = newTreshold;
    }

    /**
     * getter & setter for the multiplier which is used to calculate the amount of coins that
     * need to bid to overbid the highest bidding of an NFT.
     */
    function nftAuctionStepMultipier() public view returns (uint256){
        return _nftAuctionStepMultiplier;
    }
    function setNftAuctionStepMultipier(uint256 newMultiplier) external onlyOwnerOrAdmin {
        _nftAuctionStepMultiplier = newMultiplier;
    }

    /**
     * getter & setter for NFT auction duration once the first bid has been placed.
     */
    function nftAuctionDuration() public view returns (uint256){
        return _nftAuctionDuration;
    }
    function setNftAuctionDuration(uint256 newDuration) external onlyOwnerOrAdmin {
        _nftAuctionDuration = newDuration;
    }

    /**
     * getter & setter for NFT auction fee that the will be charged from the winner of an auction.
     */
    function nftAuctionFee() public view returns (uint256){
        return _nftAuctionFee;
    }
    function setNftAuctionFee(uint256 newFee) external onlyOwnerOrAdmin {
        _nftAuctionFee = newFee;
    }

    /* counter representing all creators that joined the AnimalHouse network */
    function creatorCount() external view returns (uint256){
        return _creatorCount;
    }

    /**
     * get the address of the collection that is assigned to the proivded owner address.
     * If the provided address is not assigned to a collection, this function will return
     * address 0x00.
     */ 
    function getCollectionByOwner(address ownerAddr) external view returns (address){
        return _ownerToCollection[ownerAddr];
    }

    /**
     * check if the provided is address is a known an valid AnimalHouse collection contract.
     */
    function isAnimalHouseCollection(address collectionAddr) external view returns (bool){
        return _collectionToValid[collectionAddr];
    }
}