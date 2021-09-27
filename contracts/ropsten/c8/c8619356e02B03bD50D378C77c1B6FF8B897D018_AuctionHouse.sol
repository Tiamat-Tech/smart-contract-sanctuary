// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./businesstwinCore.sol";

/**
 * @title Auction Repository
 * This contracts allows auctions to be created for non-fungible tokens
 * Moreover, it includes the basic functionalities of an auction house
 */
contract AuctionHouse is Ownable {
    // Array with all auctions
    Auction[] public auctions;

    // Mapping from auction index to user bids
    mapping(uint256 => Bid[]) public auctionBids;

    // Mapping from owner to a list of owned auctions
    mapping(address => uint256[]) public auctionOwner;

    // Cut owner takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,000 map to 0%-100%
    // value 1 = 0.01% | 10 = 0.1% | 100 = 1% | 1000 = 10%
    uint256 public ownerCut;

    // Bid struct to hold bidder and amount
    struct Bid {
        address from;
        uint256 amount;
    }

    address public tokenContractAddress;

    // Auction struct which holds all the required info
    struct Auction {
        uint256 auctionId;
        string name;
        uint256 endAuctionTime;
        uint256 startPrice;
        uint256 tokenId;
        address businesstwinRepositoryAddress;
        address owner;
        bool isActive;
    }

    constructor() {
        ownerCut = 0;
        tokenContractAddress = address(0x0);
    }

    /**
     * @dev Guarantees msg.sender is owner of the given auction
     * @param _auctionId uint ID of the auction to validate its ownership belongs to msg.sender
     */
    modifier isOwner(uint256 _auctionId) {
        require(auctions[_auctionId].owner == msg.sender);
        _;
    }

    /**
     * @dev Get token contract address
     * @return address representing the auction count
     */
    function gettokenContractAddress() public view returns (address) {
        return tokenContractAddress;
    }

    /**
     * @dev set token contract address
     */
    function settokenContractAddress(address _tokenContractAddress)
        public
        onlyOwner
    {
        tokenContractAddress = _tokenContractAddress;
    }

    /**
     * @dev Gets ownercut
     * @return uint representing the auction count
     */
    function getOwnersCut() public view returns (uint256) {
        return ownerCut;
    }

    /**
     * @dev sets the ownercut to value between 0 - 10000
     */
    function setOwnersCut(uint256 _ownerCut) public onlyOwner {
        if (_ownerCut > 10000 || _ownerCut < 0) {
            revert("wrong ownerCut");
        }

        ownerCut = _ownerCut;
    }

    /**
     * @dev Guarantees this contract is owner of the given token
     * @param _tokenId uint256 ID of the which has been registered in the token repository
     */
    modifier contractIsTokenOwner(uint256 _tokenId) {
        address tokenOwner = businesstwinCore(address(tokenContractAddress))
            .ownerOf(_tokenId);
        require(
            tokenOwner == msg.sender && tokenContractAddress != address(0x0)
        );
        _;
    }

    /// @dev Returns Remaining time on a auction
    function remainingTimeOnAuction(uint256 _auctionId)
        public
        view
        returns (uint256 timeRemaining)
    {
        uint256 _timeRemaining = 0;

        Auction memory auc = auctions[_auctionId];

        _timeRemaining = auc.endAuctionTime - block.timestamp;

        if (_timeRemaining < 0) {
            return 0;
        }
        return (_timeRemaining);
    }

    /**
     * @dev Gets the length of auctions
     * @return uint representing the auction count
     */
    function getCount() public view returns (uint256) {
        return auctions.length;
    }

    /**
     * @dev Gets the bid counts of a given auction
     * @param _auctionId uint ID of the auction
     */
    function getBidsCount(uint256 _auctionId) public view returns (uint256) {
        return auctionBids[_auctionId].length;
    }

    /**
     * @dev Gets the bid counts of a given auction
     * @param _auctionId uint ID of the auction
     */
    function getBidsOfAuction(uint256 _auctionId)
        public
        view
        returns (Bid[] memory)
    {
        return auctionBids[_auctionId];
    }

    /**
     * @dev Gets an array of owned auctions
     * @param _owner address of the auction owner
     */
    function getAuctionsOf(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        return auctionOwner[_owner];
    }

    /**
     * @dev Gets an array of owned auctions
     * @param _auctionId uint of the auction owner
     * @return amount uint256, address of last bidder
     */
    function getCurrentBid(uint256 _auctionId)
        public
        view
        returns (uint256, address)
    {
        uint256 bidsLength = auctionBids[_auctionId].length;
        // if there are bids refund the last bid
        if (bidsLength > 0) {
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
            return (lastBid.amount, lastBid.from);
        }
        return (0, address(0));
    }

    /**
     * @dev Gets the total number of auctions owned by an address
     * @param _owner address of the owner
     * @return uint total number of auctions
     */
    function getAuctionsCountOfOwner(address _owner)
        public
        view
        returns (uint256)
    {
        return auctionOwner[_owner].length;
    }

    /**
     * @dev Gets the info of a given auction which are stored within a struct
     * @param _auctionId uint ID of the auction
     */
    function getAuctionById(uint256 _auctionId)
        public
        view
        returns (
            uint256 auctionId,
            string memory name,
            uint256 endAuctionTime,
            uint256 startPrice,
            uint256 tokenId,
            address businesstwinRepositoryAddress,
            address owner,
            bool isActive
        )
    {
        Auction memory auc = auctions[_auctionId];
        return (
            auc.auctionId,
            auc.name,
            auc.endAuctionTime,
            auc.startPrice,
            auc.tokenId,
            auc.businesstwinRepositoryAddress,
            auc.owner,
            auc.isActive
        );
    }

    /**
     * @dev Creates an auction with the given informatin
     * @param _tokenId uint256 of the token registered in DeedRepository
     * @param _auctionTitle string containing auction title
     * @param _startPrice uint256 starting price of the auction
     * @param _endAuctionTime uint is the timestamp in which the auction expires
     * @return bool whether the auction is created
     */
    function createAuction(
        uint256 _tokenId,
        string memory _auctionTitle,
        uint256 _startPrice,
        uint256 _endAuctionTime
    ) public contractIsTokenOwner(_tokenId) returns (bool) {
        uint256 _auctionId = auctions.length;
        Auction memory newAuction;
        newAuction.auctionId = _auctionId;
        newAuction.name = _auctionTitle;
        newAuction.endAuctionTime = block.timestamp + _endAuctionTime;
        newAuction.startPrice = _startPrice;
        newAuction.tokenId = _tokenId;
        newAuction.businesstwinRepositoryAddress = tokenContractAddress;
        newAuction.owner = msg.sender;
        newAuction.isActive = true;

        auctions.push(newAuction);
        auctionOwner[msg.sender].push(_auctionId);

        approveAndTransfer(msg.sender, address(this), _tokenId);

        businesstwinCore remoteContract = businesstwinCore(
            tokenContractAddress
        );
        remoteContract.toggleForAuction(_tokenId, msg.sender);

        emit AuctionCreated(msg.sender, _auctionId);
        return true;
    }

    function approveAndTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) internal returns (bool) {
        businesstwinCore remoteContract = businesstwinCore(
            tokenContractAddress
        );
        remoteContract.approve(_to, _tokenId);
        remoteContract.transferFrom(_from, _to, _tokenId);
        return true;
    }

    /**
     * @dev Cancels an ongoing auction by the owner
     * @dev Deed is transfered back to the auction owner
     * @dev Bidder is refunded with the initial amount
     * @param _auctionId uint ID of the created auction
     */
    function cancelAuction(uint256 _auctionId) public isOwner(_auctionId) {
        Auction memory myAuction = auctions[_auctionId];
        uint256 bidsLength = auctionBids[_auctionId].length;

        // if there are bids refund the last bid
        if (bidsLength > 0) {
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
            if (!payable(lastBid.from).send(lastBid.amount)) {
                revert("Nor refund");
            }
        }

        // approve and transfer from this contract to auction owner
        if (
            approveAndTransfer(
                address(this),
                myAuction.owner,
                myAuction.tokenId
            )
        ) {
            auctions[_auctionId].isActive = false;

            businesstwinCore remoteContract = businesstwinCore(
                tokenContractAddress
            );
            remoteContract.toggleForAuction(myAuction.tokenId, msg.sender);

            emit AuctionCanceled(msg.sender, _auctionId);
        }
    }

    /**
     * @dev Finalized an ended auction
     * @dev The auction should be ended, and there should be at least one bid
     * @dev On success NFT is transfered to bidder and auction owner gets the amount
     * @param _auctionId uint ID of the created auction
     */
    function finalizeAuction(uint256 _auctionId) public {
        Auction memory myAuction = auctions[_auctionId];
        uint256 bidsLength = auctionBids[_auctionId].length;

        // 1. if auction not ended just revert
        if (block.timestamp < myAuction.endAuctionTime) revert("Not Ended");

        // if there are no bids cancel
        if (bidsLength == 0) {
            cancelAuction(_auctionId);
        } else {
            // 2. the money goes to the auction owner
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];

            // Calculate the auctioneer's cut.
            // (NOTE: _computeCut() is guaranteed to return a
            // value <= price, so this subtraction can't go negative.)
            uint256 auctioneerCut = _computeCut(lastBid.amount);
            uint256 sellerProceeds = lastBid.amount - auctioneerCut;

            if (!payable(myAuction.owner).send(sellerProceeds)) {
                revert("Not Pay Owner");
            }

            // approve and transfer from this contract to the bid winner
            if (
                approveAndTransfer(
                    address(this),
                    lastBid.from,
                    myAuction.tokenId
                )
            ) {
                auctions[_auctionId].isActive = false;

                businesstwinCore remoteContract = businesstwinCore(
                    tokenContractAddress
                );
                remoteContract.updateTokenOwnership(
                    myAuction.tokenId,
                    lastBid.from
                );
                remoteContract.toggleForAuction(myAuction.tokenId, lastBid.from);
                emit AuctionFinalized(msg.sender, _auctionId);
            }
        }
    }

    /// @dev Returns current price of an NFT on auction.
    function currentPrice(uint256 _auctionId) public view returns (uint256) {
        Auction memory myAuction = auctions[_auctionId];

        // if auction is expired
        if (block.timestamp > myAuction.endAuctionTime) {
            revert("Not Ended");
        }

        uint256 bidsLength = auctionBids[_auctionId].length;
        Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];

        return (lastBid.amount);
    }

    /**
     * @dev Bidder sends bid on an auction
     * @dev Auction should be isActive and not ended
     * @dev Refund previous bidder if a new bid is valid and placed.
     * @param _auctionId uint ID of the created auction
     */
    function bidOnAuction(uint256 _auctionId) public payable {
        uint256 ethAmountSent = msg.value;

        // owner can't bid on their auctions
        Auction memory myAuction = auctions[_auctionId];
        if (myAuction.owner == msg.sender) revert("wrong owner");

        // if auction is expired
        if (block.timestamp > myAuction.endAuctionTime) revert("Not Ended");

        uint256 bidsLength = auctionBids[_auctionId].length;
        uint256 tempAmount = myAuction.startPrice;
        Bid memory lastBid;

        // there are previous bids
        if (bidsLength > 0) {
            lastBid = auctionBids[_auctionId][bidsLength - 1];
            tempAmount = lastBid.amount;
        }

        // check if amound is greater than previous amount
        if (ethAmountSent < tempAmount) revert();

        // refund the last bidder
        if (bidsLength > 0) {
            if (!payable(lastBid.from).send(lastBid.amount)) {
                revert();
            }
        }

        // insert bid
        Bid memory newBid;
        newBid.from = msg.sender;
        newBid.amount = ethAmountSent;
        auctionBids[_auctionId].push(newBid);
        emit BidSuccess(msg.sender, _auctionId);
    }

    function withdrawBalance() external onlyOwner {
        if (msg.sender != this.owner()) {
            revert();
        }

        if (!payable(msg.sender).send(address(this).balance)) {
            revert();
        }
    }

    /// @dev Computes owner's cut of a sale.
    /// @param _price - Sale price of NFT.
    function _computeCut(uint256 _price) internal view returns (uint256) {
        // NOTE: With ownerCut <= 10000  The result of this
        //  function is always guaranteed to be <= _price.
        return (_price * ownerCut) / 10000;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function changeContractOnwner(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            transferOwnership(newOwner);
        }
    }

    /**
     * @dev Shows the current contract owner
     */
    function getContractOnwner() public view returns (address) {
        return owner();
    }

    event BidSuccess(address _from, uint256 _auctionId);

    // AuctionCreated is fired when an auction is created
    event AuctionCreated(address _owner, uint256 _auctionId);

    // AuctionCanceled is fired when an auction is canceled
    event AuctionCanceled(address _owner, uint256 _auctionId);

    // AuctionFinalized is fired when an auction is finalized
    event AuctionFinalized(address _owner, uint256 _auctionId);
}