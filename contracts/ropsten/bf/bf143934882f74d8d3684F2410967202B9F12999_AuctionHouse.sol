// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract businesstwinCollection is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    string public collectionName;
    // this contract's token symbol
    string public collectionNameSymbol;

    // define businesstwin struct
    struct Businesstwin {
        uint256 tokenId;
        string tokenName;
        string tokenURI;
        address payable mintedBy;
        address payable currentOwner;
        address payable previousOwner;
        uint256 price;
        uint256 numberOfTransfers;
        bool forSale;
    }

    // map businesstwin token id to businesstwin
    mapping(uint256 => Businesstwin) public businesstwinNFTs;
    // check if token name exists
    mapping(string => bool) public tokenNameExists;
    // check if token URI exists
    mapping(string => bool) public tokenURIExists;

    constructor() ERC721("BusinesstwinNFT", "BusinesstwinNFT") {}

    // mint a new businesstwin
    function mintbusinesstwinNFT(
        string memory _name,
        string memory _tokenURI,
        uint256 _price
    ) public {
        // check if thic fucntion caller is not an zero address account
        require(msg.sender != address(0));

        uint256 currentTokenId = _tokenIdCounter.current();

        // check if a token exists with the above token id => incremented counter
        require(!_exists(currentTokenId));

        // check if the token URI already exists or not
        require(!tokenURIExists[_tokenURI]);
        // check if the token name already exists or not
        require(!tokenNameExists[_name]);

        // mint the token
        _safeMint(msg.sender, currentTokenId);
        // set token URI (bind token id with the passed in token URI)
        _setTokenURI(currentTokenId, _tokenURI);
        _tokenIdCounter.increment();

        // make passed token URI as exists
        tokenURIExists[_tokenURI] = true;
        // make token name passed as exists
        tokenNameExists[_name] = true;

        //Converting Address to Address payable
        address payable ownerWallet = payable(msg.sender);
        address payable contractAddress = payable(address(0));

        // creat a new businesstwin (struct) and pass in new values
        Businesstwin memory newbusinesstwin = Businesstwin(
            currentTokenId,
            _name,
            _tokenURI,
            ownerWallet,
            ownerWallet,
            contractAddress,
            _price,
            0,
            true
        );
        // add the token id and it's businesstwin to all businesstwins mapping
        businesstwinNFTs[currentTokenId] = newbusinesstwin;
    }

    // get owner of the token
    function getTokenOwner(uint256 _tokenId) public view returns (address) {
        address _tokenOwner = ownerOf(_tokenId);
        return _tokenOwner;
    }

    // get metadata of the token
    function getTokenMetaData(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        string memory tokenMetaData = tokenURI(_tokenId);
        return tokenMetaData;
    }

    // get token data
    function getTokenData(uint256 _tokenId)
        public
        view
        returns (Businesstwin memory)
    {
        Businesstwin memory tokenData = businesstwinNFTs[_tokenId];
        return tokenData;
    }

    // get total number of tokens minted so far
    function getNumberOfTokensMinted() public view returns (uint256) {
        uint256 totalNumberOfTokensMinted = totalSupply();
        return totalNumberOfTokensMinted;
    }

    // get total number of tokens owned by an address
    function getTotalNumberOfTokensOwnedByAnAddress(address _owner)
        public
        view
        returns (uint256)
    {
        uint256 totalNumberOfTokensOwned = balanceOf(_owner);
        return totalNumberOfTokensOwned;
    }

    // check if the token already exists
    function getTokenExists(uint256 _tokenId) public view returns (bool) {
        bool tokenExists = _exists(_tokenId);
        return tokenExists;
    }

    function getTokenIsForSale(uint256 _tokenId) public view returns (bool) {
        require(_exists(_tokenId), "token does not exist");
        return businesstwinNFTs[_tokenId].forSale;
    }

    function changeTokenPrice(uint256 _tokenId, uint256 _newPrice) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // update token's price with new price
        businesstwin.price = _newPrice;
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;
    }

    // switch between set for sale and set not for sale
    function toggleForSale(uint256 _tokenId) public {
        // require caller of the function is not an empty address
        require(msg.sender != address(0));
        // require that token should exist
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // check that token's owner should be equal to the caller of the function
        require(tokenOwner == msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // if token's forSale is false make it true and vice versa
        if (businesstwin.forSale) {
            businesstwin.forSale = false;
        } else {
            businesstwin.forSale = true;
        }
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;
    }

    // buy a token by passing in the token's id
    function buyToken(uint256 _tokenId) public payable {
        // check if the function caller is not an zero account address
        require(msg.sender != address(0));
        // check if the token id of the token being bought exists or not
        require(_exists(_tokenId));
        // get the token's owner
        address tokenOwner = ownerOf(_tokenId);
        // token's owner should not be an zero address account
        require(tokenOwner != address(0));
        // the one who wants to buy the token should not be the token's owner
        require(tokenOwner != msg.sender);
        // get that token from all businesstwins mapping and create a memory of it defined as (struct => businesstwin)
        Businesstwin memory businesstwin = businesstwinNFTs[_tokenId];
        // price sent in to buy should be equal to or more than the token's price
        require(msg.value >= businesstwin.price, "Price to low");
        // token should be for sale
        require(businesstwin.forSale);
        // transfer the token from owner to the caller of the function (buyer)
        _transfer(tokenOwner, msg.sender, _tokenId);
        // get owner of the token
        address payable sendTo = businesstwin.currentOwner;
        // send token's worth of ethers to the owner
        sendTo.transfer(msg.value);
        // update the token's previous owner
        businesstwin.previousOwner = businesstwin.currentOwner;
        //Converting Address to Address payable
        address payable newOwnerAddress = payable(msg.sender);
        // update the token's current owner
        businesstwin.currentOwner = newOwnerAddress;
        // update the how many times this token was transfered
        businesstwin.numberOfTransfers += 1;
        // set and update that token in the mapping
        businesstwinNFTs[_tokenId] = businesstwin;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * @title Auction Repository
 * This contracts allows auctions to be created for non-fungible tokens
 * Moreover, it includes the basic functionalities of an auction house
 */
contract AuctionHouse {
    // Array with all auctions
    Auction[] public auctions;

    // Mapping from auction index to user bids
    mapping(uint256 => Bid[]) public auctionBids;

    // Mapping from owner to a list of owned auctions
    mapping(address => uint256[]) public auctionOwner;

    // Bid struct to hold bidder and amount
    struct Bid {
        address from;
        uint256 amount;
    }

    // Auction struct which holds all the required info
    struct Auction {
        string name;
        uint256 endAuctionTime;
        uint256 startPrice;
        uint256 tokenId;
        address businesstwinRepositoryAddress;
        address owner;
        bool isActive;
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
     * @dev Guarantees this contract is owner of the given deed/token
     * @param _businesstwinRepositoryAddress address of the businesstwin repository to validate from
     * @param _tokenId uint256 ID of the deed which has been registered in the deed repository
     */
    modifier contractIsTokenOwner(
        address _businesstwinRepositoryAddress,
        uint256 _tokenId
    ) {
        address tokenOwner = businesstwinCollection(address(_businesstwinRepositoryAddress)).ownerOf(_tokenId);
        require(tokenOwner == msg.sender, "Auction Can only be Created by Tken Owner");
        _;
    }

    // /**
    // * @dev Disallow payments to this contract directly
    // */
    // function() public{
    //     revert();
    // }

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
     * @dev Gets an array of owned auctions
     * @param _owner address of the auction owner
     */
    function getAuctionsOf(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory ownedAuctions = auctionOwner[_owner];
        return ownedAuctions;
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
     * @param _businesstwinRepositoryAddress address of the DeedRepository contract
     * @param _tokenId uint256 of the deed registered in DeedRepository
     * @param _auctionTitle string containing auction title
     * @param _startPrice uint256 starting price of the auction
     * @param _endAuctionTime uint is the timestamp in which the auction expires
     * @return bool whether the auction is created
     */
    function createAuction(
        address _businesstwinRepositoryAddress,
        uint256 _tokenId,
        string memory _auctionTitle,
        uint256 _startPrice,
        uint256 _endAuctionTime
    )
        public
        contractIsTokenOwner(_businesstwinRepositoryAddress, _tokenId)
        returns (bool)
    {
        uint256 auctionId = auctions.length;
        Auction memory newAuction;
        newAuction.name = _auctionTitle;
        newAuction.endAuctionTime = block.timestamp + _endAuctionTime;
        newAuction.startPrice = _startPrice;
        newAuction.tokenId = _tokenId;
        newAuction
            .businesstwinRepositoryAddress = _businesstwinRepositoryAddress;
        newAuction.owner = msg.sender;
        newAuction.isActive = true;

        auctions.push(newAuction);
        auctionOwner[msg.sender].push(auctionId);

        approveAndTransfer(msg.sender, address(this), _businesstwinRepositoryAddress, _tokenId);

        emit AuctionCreated(msg.sender, auctionId);
        return true;
    }

    function approveAndTransfer(
        address _from,
        address _to,
        address _businesstwinRepositoryAddress,
        uint256 _tokenId
    ) internal returns (bool) {
        businesstwinCollection remoteContract = businesstwinCollection(
            _businesstwinRepositoryAddress
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
                revert("could not refund the last bidder");
            }
        }

        // approve and transfer from this contract to auction owner
        if (
            approveAndTransfer(
                address(this),
                myAuction.owner,
                myAuction.businesstwinRepositoryAddress,
                myAuction.tokenId
            )
        ) {
            auctions[_auctionId].isActive = false;
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
        if (block.timestamp < myAuction.endAuctionTime) revert("Block Timestamp greater than auction deadline");

        // if there are no bids cancel
        if (bidsLength == 0) {
            cancelAuction(_auctionId);
        } else {
            // 2. the money goes to the auction owner
            Bid memory lastBid = auctionBids[_auctionId][bidsLength - 1];
            if (!payable(myAuction.owner).send(lastBid.amount)) {
                revert("could not pay highest bid to auction owner");
            }

            // approve and transfer from this contract to the bid winner
            if (
                approveAndTransfer(
                    address(this),
                    lastBid.from,
                    myAuction.businesstwinRepositoryAddress,
                    myAuction.tokenId
                )
            ) {
                auctions[_auctionId].isActive = false;
                emit AuctionFinalized(msg.sender, _auctionId);
            }
        }
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
        if (myAuction.owner == msg.sender) revert("Onwner cannot bid on own auction");

        // if auction is expired
        if (block.timestamp > myAuction.endAuctionTime) revert("Block Timestamp greater than auction deadline");

        uint256 bidsLength = auctionBids[_auctionId].length;
        uint256 tempAmount = myAuction.startPrice;
        Bid memory lastBid;

        // there are previous bids
        if (bidsLength > 0) {
            lastBid = auctionBids[_auctionId][bidsLength - 1];
            tempAmount = lastBid.amount;
        }

        // check if amound is greater than previous amount
        if (ethAmountSent < tempAmount) revert("ether sent less than highest bid amount ");

        // refund the last bidder
        if (bidsLength > 0) {
            if (!payable(lastBid.from).send(lastBid.amount)) {
                revert("Could not refound last bidder");
            }
        }

        // insert bid
        Bid memory newBid;
        newBid.from = msg.sender;
        newBid.amount = ethAmountSent;
        auctionBids[_auctionId].push(newBid);
        emit BidSuccess(msg.sender, _auctionId);
    }

    event BidSuccess(address _from, uint256 _auctionId);

    // AuctionCreated is fired when an auction is created
    event AuctionCreated(address _owner, uint256 _auctionId);

    // AuctionCanceled is fired when an auction is canceled
    event AuctionCanceled(address _owner, uint256 _auctionId);

    // AuctionFinalized is fired when an auction is finalized
    event AuctionFinalized(address _owner, uint256 _auctionId);
}