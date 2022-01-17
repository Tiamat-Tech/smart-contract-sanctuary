// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
// import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './NFTAuctionStorage.sol';
import './erc2981/IERC2981Royalties.sol';

contract NFTAuction is Ownable, Pausable, NFTAuctionStorage, IERC721Receiver {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    EnumerableSet.AddressSet private _contractWhitelist;

    // constants
    address constant ADDRESS_NULL = address(0);
    uint256 constant biddingTime = 3 minutes;
    uint256 constant platformFee = 5;
    uint256 constant feePercentage = 100;

    // state
    mapping(address => EnumerableSet.UintSet)
        private _contractsToSenderTokenIdList;
    mapping(uint256 => Auction) private _contractsTokenIdToAuction;

    constructor(address payable _recipientAddress) {
        recipientAddress = _recipientAddress;
    }

    function addWhitelistContract(address _nftContract) public onlyOwner {
        _contractWhitelist.add(_nftContract);
    }

    function deleteWhitelistContract(address _nftContract) public onlyOwner {
        _contractWhitelist.remove(_nftContract);
    }

    function isWhitelistContract(address _nftContract)
        public
        view
        returns (bool)
    {
        return _contractWhitelist.contains(_nftContract);
    }

    function getNFTAuctionIdList(address _nftContract)
        public
        view
        returns (uint256[] memory)
    {
        return _contractsToSenderTokenIdList[_nftContract].values();
    }

    function getAuction(address _nftContract, uint256 _tokenId)
        public
        view
        returns (
            address,
            uint256,
            uint256,
            address,
            uint256,
            uint256
        )
    {
        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        return (
            _contractsTokenIdToAuction[auctionId].seller,
            _contractsTokenIdToAuction[auctionId].startedAt,
            _contractsTokenIdToAuction[auctionId].endedAt,
            _contractsTokenIdToAuction[auctionId].highestBidder,
            _contractsTokenIdToAuction[auctionId].highestBidPrice,
            _contractsTokenIdToAuction[auctionId].bidders.length
        );
    }

    function getBids(address _nftContract, uint256 _tokenId)
        public
        view
        returns (Bidder[] memory)
    {
        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        return _contractsTokenIdToAuction[auctionId].bidders;
    }

    function createAuction(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    ) public onlyOwner whenNotPaused {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            'sender dont own tokenId'
        );
        uint256 sellerindex = toUint256(msg.sender).add(_tokenId);
        require(
            !_contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'auction is already created'
        );

        IERC721(_nftContract).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        Auction storage auction = _contractsTokenIdToAuction[auctionId];
        auction.seller = msg.sender;
        auction.highestBidder = address(0);
        auction.highestBidPrice = _price;
        auction.highestBidAt = block.timestamp;
        auction.amount = 0;
        auction.startedAt = block.timestamp;
        auction.endedAt = block.timestamp.add(biddingTime);

        _contractsToSenderTokenIdList[_nftContract].add(sellerindex);

        emit AuctionCreated(
            _nftContract,
            _tokenId,
            auctionId,
            msg.sender,
            _price
        );
    }

    function bid(address _nftContract, uint256 _tokenId)
        public
        payable
        whenNotPaused
    {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );

        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        Auction storage auction = _contractsTokenIdToAuction[auctionId];

        require(
            auction.seller != ADDRESS_NULL && auction.seller != msg.sender,
            'wrong seller address'
        );
        uint256 sellerindex = toUint256(auction.seller).add(_tokenId);
        require(
            _contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'auction is not created'
        );

        require(block.timestamp < auction.endedAt, 'auction finished');
        require(
            msg.value > auction.highestBidPrice,
            'bid price must be more than previous bid'
        );

        if (auction.highestBidder != ADDRESS_NULL) {
            payable(auction.highestBidder).transfer(auction.highestBidPrice);
        }

        auction.highestBidder = msg.sender;
        auction.highestBidPrice = msg.value;
        auction.highestBidAt = block.timestamp;
        auction.amount += msg.value;
        auction.bidders.push(Bidder(msg.sender, msg.value, block.timestamp));

        emit AuctionBidden(
            _nftContract,
            _tokenId,
            auctionId,
            msg.sender,
            msg.value
        );
    }

    function finishAuction(address _nftContract, uint256 _tokenId)
        public
        onlyOwner
        whenNotPaused
    {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );

        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        Auction storage auction = _contractsTokenIdToAuction[auctionId];

        require(auction.seller != ADDRESS_NULL, 'wrong seller address');
        uint256 sellerindex = toUint256(auction.seller).add(_tokenId);
        require(
            _contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'auction is not created'
        );

        require(block.timestamp > auction.endedAt, 'auction not finished yet');

        if (
            auction.bidders.length > 0 && auction.highestBidder != ADDRESS_NULL
        ) {
            IERC721(_nftContract).safeTransferFrom(
                address(this),
                auction.highestBidder,
                _tokenId
            );

            uint256 recipientAmount = auction
                .highestBidPrice
                .mul(platformFee)
                .div(feePercentage);

            address brandAddress;
            uint256 brandFee;
            address collabAddress;
            uint256 collabFee;
            (
                brandAddress,
                brandFee,
                collabAddress,
                collabFee
            ) = IERC2981Royalties(_nftContract).royaltyInfo(_tokenId);

            if (brandAddress != ADDRESS_NULL) {
                brandFee = auction.highestBidPrice.mul(brandFee).div(
                    feePercentage
                );
            }
            if (collabAddress != ADDRESS_NULL) {
                collabFee = auction.highestBidPrice.mul(brandFee).div(
                    feePercentage
                );
            }

            uint256 sellAmount = auction
                .highestBidPrice
                .sub(recipientAmount)
                .sub(brandFee)
                .sub(collabFee);

            recipientAddress.transfer(recipientAmount);
            if (brandAddress != ADDRESS_NULL)
                payable(brandAddress).transfer(brandFee);
            if (collabAddress != ADDRESS_NULL)
                payable(collabAddress).transfer(collabFee);
            payable(auction.seller).transfer(sellAmount);
        } else {
            IERC721(_nftContract).safeTransferFrom(
                address(this),
                auction.seller,
                _tokenId
            );
        }

        delete _contractsTokenIdToAuction[auctionId];
        _contractsToSenderTokenIdList[_nftContract].remove(sellerindex);

        emit AuctionFinished(_nftContract, _tokenId, auctionId);
    }

    function cancelAuction(address _nftContract, uint256 _tokenId)
        public
        onlyOwner
        whenNotPaused
    {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );

        uint256 auctionId = toUint256(_nftContract).add(_tokenId);
        Auction storage auction = _contractsTokenIdToAuction[auctionId];

        require(auction.seller != ADDRESS_NULL, 'wrong seller address');
        uint256 sellerindex = toUint256(auction.seller).add(_tokenId);
        require(
            _contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'auction is not created'
        );

        require(block.timestamp < auction.endedAt, 'auction not finished yet');

        IERC721(_nftContract).safeTransferFrom(
            address(this),
            auction.seller,
            _tokenId
        );

        if (
            auction.bidders.length > 0 && auction.highestBidder != ADDRESS_NULL
        ) {
            payable(auction.highestBidder).transfer(auction.highestBidPrice);
        }

        delete _contractsTokenIdToAuction[auctionId];
        _contractsToSenderTokenIdList[_nftContract].remove(sellerindex);

        emit AuctionCanceld(_nftContract, _tokenId, auctionId);
    }

    bytes4 constant ERC721_ONRECEIVED_RESULT = bytes4(
        keccak256('onERC721Received(address,address,uint256,bytes)')
    );

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return
            bytes4(
                keccak256('onERC721Received(address,address,uint256,bytes)')
            );
    }

    fallback() external {
        revert();
    }
}