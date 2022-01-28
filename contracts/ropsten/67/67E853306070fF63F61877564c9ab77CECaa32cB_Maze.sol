/// SPDX-License-Identifier: MIT
/// Maze Protocol Contracts v1.0.0 (Maze.sol)

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Maze is Ownable, Pausable, IERC721Receiver {
    /// @dev The ERC-165 interface signature for ERC-721.
    //  Ref: https://eips.ethereum.org/EIPS/eip-721
    //  type(IERC721).interfaceId == 0x80ac58cd
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = bytes4(0x80ac58cd);

    // Auction type
    enum AuctionType {
        Radical,
        Dutch,
        Fixed
    }

    struct AuctionParam {
        // all NFT of a contract support auction types
        // only one auction type for a contract
        AuctionType auctionType;
        // auction fee ratio, to maze protocol
        // fee = amount / feeRatio
        uint128 feeRatio;
        // auction tax ratio
        // tax = amount / taxRatio
        uint128 taxRatio;
        // NFT creator
        address taxReceiver;
    }

    // Represents an auction on an NFT
    struct Auction {
        // current NFT owner
        address seller;
        // for NFT creator initial radical auction
        uint128 initialPrice;
        // for radical auction
        uint128 deposit;
        // for fixed auction
        uint128 fixedPrice;
        // for dutch auction
        uint128 startPrice;
        // for dutch auction
        uint128 endPrice;
        // auction start timestamp
        //0 means auction is not start
        uint64 startedAt;
        // for dutch auction
        uint64 duration;
    }

    // Represents an offer on an NFT
    struct Offer {
        // offer provider
        address buyer;
        // buy NFT price
        uint128 offerPrice;
    }

    // address receive maze protocol fee
    address public feeReceiver;

    // supported contracts
    address[] internal supportedContracts;

    // storage nft contract address to auction parameter
    mapping(address => AuctionParam) internal contractToAuctionParams;

    // storage nft contract address to nft auction
    mapping(address => mapping(uint256 => Auction)) internal contractTokenIdToAuction;

    // storage nft contract address to nft offers
    mapping(address => mapping(uint256 => Offer[])) internal contractTokenIdToOffer;

    // auction created event
    event AuctionCreated(address indexed contractAddress, uint256 tokenId, address indexed seller);

    // auction successful event
    event AuctionSuccessful(address indexed contractAddress, uint256 tokenId, uint256 price, address indexed winner);

    // auction cancelled event
    event AuctionCancelled(address indexed contractAddress, uint256 tokenId);

    constructor() {
        // starts paused.
        pause();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    // NFTs of ERC721 only could be auctioned after maze protocol owner call this function set
    // the ERC721 contract address and auction parameter to contractToAuctionParams.
    function setAuctionParam(
        address _contractAddress,
        uint8 _auctionType,
        uint128 _feeRatio,
        uint128 _taxRatio,
        address _taxReceiver
    ) external onlyOwner {
        IERC721 nonFungibleContract = IERC721(_contractAddress);
        require(nonFungibleContract.supportsInterface(INTERFACE_SIGNATURE_ERC721), "Not support contract interface.");

        // Radical 0, Dutch 1, Fixed 2
        require(_auctionType < 3, "Invalid auction type.");
        require(_feeRatio > 0, "Invalid fee ratio.");
        require(_taxRatio > 0, "Invalid tax ratio.");
        require(_taxReceiver != address(0), "Invalid tax receiver.");

        AuctionParam memory auctionParam = AuctionParam(AuctionType(_auctionType), _feeRatio, _taxRatio, _taxReceiver);
        contractToAuctionParams[_contractAddress] = auctionParam;

        supportedContracts.push(_contractAddress);
    }

    // Create radical auction only could be called by NFT creator.
    function createInitialRadicalAuction(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _initialPrice
    ) external whenNotPaused {
        // check support radical auction
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        require(auctionParam.auctionType == AuctionType.Radical, "Not support radical auction.");
        _checkAuctionParam(auctionParam);

        // check initial price
        require(_initialPrice == uint256(uint128(_initialPrice)), "Initial price is invalid.");

        // check is nft creator
        require(msg.sender == auctionParam.taxReceiver, "Not nft creator");

        // check ownership
        IERC721 nonFungibleContract = IERC721(_contractAddress);
        require(msg.sender == nonFungibleContract.ownerOf(_tokenId), "Not token owner.");

        // check auction exist
        Auction memory auction = contractTokenIdToAuction[_contractAddress][_tokenId];
        require(auction.startedAt == 0, "Auction is already start.");

        // transfer ownership before auction created
        // need user send a setApprovalForAll transaction to ERC721 contract before this
        // frontend check isApprovedForAll for msg.sender
        nonFungibleContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        _createAuction(_contractAddress, _tokenId, msg.sender, _initialPrice, 0, 0, 0, 0, 0);
    }

    // Create radical auction when auction type of contract address contain radical.
    function createRadicalAuction(address _contractAddress, uint256 _tokenId) external payable whenNotPaused {
        // check support radical auction
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        require(auctionParam.auctionType == AuctionType.Radical, "Not support radical auction.");
        _checkAuctionParam(auctionParam);

        // check ownership
        IERC721 nonFungibleContract = IERC721(_contractAddress);
        require(msg.sender == nonFungibleContract.ownerOf(_tokenId), "Not token owner.");

        // check auction exist
        Auction memory auction = contractTokenIdToAuction[_contractAddress][_tokenId];
        require(auction.startedAt == 0, "Auction is already start.");

        // check radical auction deposit
        require(msg.value > 0, "No radical auction deposit");

        // transfer ownership before auction created
        // need user send a setApprovalForAll transaction to ERC721 contract before this
        // frontend check isApprovedForAll for msg.sender
        nonFungibleContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        // create auction
        _createAuction(_contractAddress, _tokenId, msg.sender, 0, msg.value, 0, 0, 0, 0);
    }

    function bidRadicalAuction(address _contractAddress, uint256 _tokenId) external payable whenNotPaused {
        // check support radical auction
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        require(auctionParam.auctionType == AuctionType.Radical, "Not support radical auction.");
        _checkAuctionParam(auctionParam);

        Auction memory auction = contractTokenIdToAuction[_contractAddress][_tokenId];
        require(auction.startedAt != 0, "Auction is not start.");
        require(msg.sender != auction.seller, "Can't bid own auction.");

        uint256 dealPrice = _currentPrice(auctionParam, auction);
        uint256 feeAmount = dealPrice / uint256(auctionParam.feeRatio);
        uint256 taxAmount = dealPrice / uint256(auctionParam.taxRatio);

        require(msg.value > (dealPrice + feeAmount + taxAmount), "Insufficient payable amount.");

        // remove from contractTokenIdToAuction
        delete contractTokenIdToAuction[_contractAddress][_tokenId];

        // remove token auction offers
        delete contractTokenIdToOffer[_contractAddress][_tokenId];

        payable(auction.seller).transfer(dealPrice);
        payable(auction.seller).transfer(uint256(auction.deposit));
        payable(feeReceiver).transfer(feeAmount);
        payable(auctionParam.taxReceiver).transfer(taxAmount);

        emit AuctionSuccessful(_contractAddress, _tokenId, dealPrice, msg.sender);

        // will never underflow
        uint256 newDeposit = msg.value - dealPrice - feeAmount - taxAmount;

        // create new auction
        _createAuction(_contractAddress, _tokenId, msg.sender, 0, newDeposit, 0, 0, 0, 0);
    }

    // Only can cancel radical auction when maze protocol contract paused.
    function cancelRadicalAuctionWhenPaused(address _contractAddress, uint256 _tokenId) external whenPaused onlyOwner {
        // check support radical auction
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        require(auctionParam.auctionType == AuctionType.Radical, "Not support radical auction.");
        _checkAuctionParam(auctionParam);

        Auction memory auction = contractTokenIdToAuction[_contractAddress][_tokenId];
        require(auction.startedAt != 0, "Auction is not start.");

        // remove from contractTokenIdToAuction
        delete contractTokenIdToAuction[_contractAddress][_tokenId];

        // remove token auction offer
        delete contractTokenIdToOffer[_contractAddress][_tokenId];

        IERC721 nonFungibleContract = IERC721(_contractAddress);
        // transfer ownership after auction deleted
        nonFungibleContract.safeTransferFrom(address(this), auction.seller, _tokenId);

        payable(auction.seller).transfer(auction.deposit);

        emit AuctionCancelled(_contractAddress, _tokenId);
    }

    function getSupportedContracts() external view returns (address[] memory) {
        return supportedContracts;
    }

    function getAuctionParam(address _contractAddress)
        external
        view
        returns (
            uint8 auctionType,
            uint256 feeRatio,
            uint256 taxRatio,
            address taxReceiver
        )
    {
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        _checkAuctionParam(auctionParam);

        auctionType = uint8(auctionParam.auctionType);
        feeRatio = uint256(auctionParam.feeRatio);
        taxRatio = uint256(auctionParam.taxRatio);
        taxReceiver = auctionParam.taxReceiver;
    }

    // Returns auction info for an NFT on auction.
    function getAuction(address _contractAddress, uint256 _tokenId)
        external
        view
        returns (
            address seller,
            uint8 auctionType,
            uint256 deposit,
            uint256 startPrice,
            uint256 endPrice,
            uint256 fixedPrice,
            uint256 currentPrice,
            uint64 startedAt,
            uint64 duration
        )
    {
        AuctionParam memory auctionParam = contractToAuctionParams[_contractAddress];
        _checkAuctionParam(auctionParam);

        Auction memory auction = contractTokenIdToAuction[_contractAddress][_tokenId];
        require(auction.startedAt != 0, "Auction is not start.");

        seller = auction.seller;
        auctionType = uint8(auctionParam.auctionType);
        deposit = uint256(auction.deposit);
        startPrice = uint256(auction.startPrice);
        endPrice = uint256(auction.endPrice);
        fixedPrice = uint256(auction.fixedPrice);
        currentPrice = _currentPrice(auctionParam, auction);
        startedAt = auction.startedAt;
        duration = auction.duration;
    }

    function _checkAuctionParam(AuctionParam memory auctionParam) internal pure {
        require(auctionParam.feeRatio > 0, "Invalid fee ratio.");
        require(auctionParam.taxRatio > 0, "Invalid tax ratio.");
        require(auctionParam.taxReceiver != address(0), "Invalid tax receiver");
    }

    function _createAuction(
        address _contractAddress,
        uint256 _tokenId,
        address _seller,
        uint256 _initialPrice,
        uint256 _deposit,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _fixedPrice,
        uint64 _duration
    ) internal {
        require(_initialPrice == uint256(uint128(_initialPrice)), "Initial price is invalid.");
        require(_deposit == uint256(uint128(_deposit)), "Deposit is invalid.");
        require(_startPrice == uint256(uint128(_startPrice)), "Start price is invalid.");
        require(_endPrice == uint256(uint128(_endPrice)), "End price is invalid.");
        require(_fixedPrice == uint256(uint128(_fixedPrice)), "Fixed price is invalid.");

        Auction memory auction = Auction(
            _seller,
            uint128(_initialPrice),
            uint128(_deposit),
            uint128(_startPrice),
            uint128(_endPrice),
            uint128(_fixedPrice),
            uint64(block.timestamp),
            _duration
        );

        contractTokenIdToAuction[_contractAddress][_tokenId] = auction;

        emit AuctionCreated(_contractAddress, _tokenId, _seller);
    }

    function _currentPrice(AuctionParam memory auctionParam, Auction memory auction) internal pure returns (uint256) {
        if (auctionParam.auctionType == AuctionType.Radical) {
            // support nft creator create radical auction without deposit
            if (auction.seller == auctionParam.taxReceiver && auction.initialPrice != 0) {
                return uint256(auction.initialPrice);
            }
            return uint256(auction.deposit) * 10;
        }

        if (auctionParam.auctionType == AuctionType.Dutch) {
            // TODO
            return 0;
        }

        if (auctionParam.auctionType == AuctionType.Fixed) {
            return uint256(auction.fixedPrice);
        }

        revert("Invalid auction type.");
    }

    /// Pause maze protocol contract.
    function pause() public onlyOwner whenNotPaused {
        super._pause();
    }

    /// @dev Override unpause so it requires all external contract addresses
    function unpause() public onlyOwner whenPaused {
        require(feeReceiver != address(0), "fee receiver is not ready.");
        // Actually unpause the contract.
        super._unpause();
    }
}