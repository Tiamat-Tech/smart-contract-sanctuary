// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Spactio is Ownable {

    uint256 public totalFees = 0;

    event NewAuction(address indexed seller, address indexed smartContract, uint256 indexed tokenId, uint256 minimumPrice, uint256 id);

    struct Auction {
        bool valid;
        bool is721;
        uint256 startDate;
        uint256 endDate;
        address smartContract;
        uint256 tokenId;
        address seller;
        address highestBidder;
        uint256 minimumPrice;
        uint256 currentPrice;
        bool finished;
    }
    
    mapping(uint256 => Auction) auctions;

    function createAuction(address _smartContract, uint256 _tokenId, uint256 _minimumPrice, bool _is721) public {
        uint256 id = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, _smartContract, _tokenId, _minimumPrice)));
        require(!auctions[id].valid, "The auction already exists");
        require(_minimumPrice > 0, "Invalid price");
        require(_smartContract != address(0), "Invalid smart contract");
        require(_tokenId > 0, "Invalid token Id");

        if (_is721) {
            ERC721(_smartContract).transferFrom(msg.sender, address(this), _tokenId);
        } else {
            ERC1155(_smartContract).safeTransferFrom(msg.sender, address(this), _tokenId, 1, "0x0");
        }
        
        Auction memory o;
        o.valid = true;
        o.seller = msg.sender;
        o.smartContract = _smartContract;
        o.is721 = _is721;
        o.tokenId = _tokenId;
        o.minimumPrice = _minimumPrice;
        o.startDate = block.timestamp;
        o.endDate = block.timestamp + 30 days;
        
        auctions[id] = o;
        
        emit NewAuction(msg.sender, _smartContract, _tokenId, _minimumPrice, id);
    }

    function claimAuction(uint256 _id) public {
        require(auctions[_id].valid, "Invalid auction");
        require(auctions[_id].endDate < block.timestamp, "Still not finished");
        require(auctions[_id].highestBidder == msg.sender, "Not the highest bidder");

        Auction storage auction = auctions[_id];
        auction.finished = true;
        uint256 totalAmount = auction.currentPrice * 9 / 10;
        payable(auction.seller).transfer(totalAmount);
        totalFees += auction.currentPrice - totalAmount; 

        if (auction.is721) {
            ERC721(auction.smartContract).transferFrom(address(this), msg.sender, auction.tokenId);
        } else {
            ERC1155(auction.smartContract).safeTransferFrom(address(this), msg.sender, auction.tokenId, 1, "0x0");
        }
    }

    function bid(uint256 _id, uint256 _amount) public {
        require(auctions[_id].valid, "Invalid auction");
        require(!auctions[_id].finished, "Already finished");
        require(_amount > auctions[_id].currentPrice, "Invalid bid");

        Auction storage auction = auctions[_id];

        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.currentPrice);
        }

        auction.highestBidder = msg.sender;
        auction.currentPrice = _amount;
    }

    function cancelAuction(uint256 _id) public {
        require(auctions[_id].valid, "Invalid auction");
        require(!auctions[_id].finished, "Already finished");
        require(auctions[_id].highestBidder == address(0), "Already a bid");
        require(auctions[_id].seller == msg.sender, "Not the seller");

        Auction storage auction = auctions[_id];
        auction.valid = false;

        if (auction.is721) {
            ERC721(auction.smartContract).transferFrom(address(this), msg.sender, auction.tokenId);
        } else {
            ERC1155(auction.smartContract).safeTransferFrom(address(this), msg.sender, auction.tokenId, 1, "0x0");
        }
    }

    function withdrawFees() public onlyOwner {
        uint256 total = totalFees;
        totalFees = 0;
        payable(msg.sender).transfer(total);
    }
}