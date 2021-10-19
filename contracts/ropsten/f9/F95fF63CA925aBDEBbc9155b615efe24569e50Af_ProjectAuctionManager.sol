// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./SendValueWithFallbackWithdraw.sol";
import "../../access/SignerRoleUpgradeable.sol";
import "../helper/WithTreasuryUpgradeable.sol";

/**
 * @notice Manages a minimum price auction for NFTs.
 */
contract ProjectAuctionManager is
    Initializable,
    OwnableUpgradeable,
    SignerRoleUpgradeable,
    WithTreasuryUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    SendValueWithFallbackWithdraw,
    UUPSUpgradeable
{
    using AddressUpgradeable for address;

    /* ========== STRUCTS ========== */
    struct Auction {
        uint256 startTime;
        uint256 endTime;
        uint256 extDurationMinutes;
        uint256 minPercentIncrementInBasisPoints;
        address payable bidder;
        uint256 amount;
        string tokenURI;
        ERC721ProjectUpgradeable project;
        bool finalized;
    }

    /* ========== CONSTANTS ============= */
    // Cap the max duration so that overflows will not occur
    uint256 private constant MAX_MAX_DURATION = 1000 days;

    uint256 internal constant BASIS_POINTS = 10000;

    /* ========== STATE VARIABLES ========== */

    uint256 public nextAuctionId;

    mapping(uint256 => Auction) private auctions;

    // dev: set to true if whitelist is needed for auction
    bool private shouldVerifySignatureForBid;

    /* ========== EVENTS ========== */

    event ShouldVerifySignatureUpdated(bool shouldVerifySignatureForBid);

    event AuctionCreated(uint256 indexed auctionId, Auction auction);
    event AuctionUpdated(uint256 indexed auctionId, Auction auction);
    event AuctionCanceled(uint256 indexed auctionId);
    event AuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 endTime);
    event AuctionOutBid(address indexed previousBidder, uint256 previousAmount);
    event AuctionFinalized(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address project,
        uint256 tokenId
    );
    event AuctionCanceledByAdmin(uint256 indexed auctionId, string reason);

    /* ========== MODIFIERS ========== */

    modifier onlyValidAuctionConfig(Auction calldata auction) {
        require(auction.bidder == address(0), "bad bidder");
        require(!auction.finalized, "finalized should be false");
        require(bytes(auction.tokenURI).length > 0, "bad tokenURI");
        require(address(auction.project).isContract(), "bad project address");
        require(auction.endTime > block.timestamp, "endTime should > now");
        require(auction.endTime - auction.startTime <= MAX_MAX_DURATION, "Duration must be <= 1000 days");
        require(
            auction.endTime - auction.startTime >= auction.extDurationMinutes * 1 minutes,
            "Duration must be >= extDurationMinutes"
        );
        _;
    }

    /* ========== INITIALIZER ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address treasuryAddress) public initializer {
        __Ownable_init();
        __SignerRole_init();
        __WithTreasury_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __SendValueWithFallbackWithdraw_init();
        __UUPSUpgradeable_init();

        shouldVerifySignatureForBid = true;
        nextAuctionId = 1;
        setTreasury(payable(treasuryAddress));
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Returns auction details for a given auctionId.
     */
    function getAuction(uint256 auctionId) public view returns (Auction memory) {
        return auctions[auctionId];
    }

    /**
     * @notice Returns the minimum amount a bidder must spend to participate in an auction.
     */
    function getMinBidAmount(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (auction.bidder == address(0)) {
            if (auction.amount == 0) {
                // The next bid must be at least 1 wei greater if initial amount is 0;
                return auction.amount + 1;
            } else {
                return auction.amount;
            }
        }
        return _getMinBidAmountForAuction(auction.amount, auction.minPercentIncrementInBasisPoints);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice A bidder may place a bid which is at least the value defined by `getMinBidAmount`.
     * If there is already an outstanding bid, the previous bidder will be refunded at this time
     * and if the bid is placed in the final moments of the auction, the countdown may be extended.
     * if *shouldVerifySignatureForBid* is set, a valid signature should be provided.
     */
    function placeBid(
        uint256 auctionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable nonReentrant whenNotPaused {
        // check auction status before signature verification, save some gas if auction is over
        Auction storage auction = auctions[auctionId];
        require(bytes(auction.tokenURI).length > 0, "ProjectAuction: Auction not found");
        require(auction.startTime <= block.timestamp, "ProjectAuction: Auction is not started yet");
        require(auction.endTime >= block.timestamp, "ProjectAuction: Auction is over");

        if (shouldVerifySignatureForBid) {
            bytes32 messageHash = keccak256(abi.encode(block.chainid, address(this), _msgSender(), auctionId));
            require(_verifySignedMessage(messageHash, v, r, s), "ProjectAuction: proper signature is required");
        }

        if (auction.bidder == address(0)) {
            // it's the first bid
            // if the min price is 0, ensure it's > 0
            // if the min price larger than 0, ensure it's >= min price
            require(
                (auction.amount == 0 && msg.value > auction.amount) ||
                    (auction.amount != 0 && msg.value >= auction.amount),
                "ProjectAuction: Bid must be at least the min price and higher than 0"
            );
            auction.amount = msg.value;
            auction.bidder = payable(_msgSender());
        } else {
            // If this bid outbids another, confirm that the bid is at least x% greater than the last
            require(auction.bidder != _msgSender(), "ProjectAuction: You already have an outstanding bid");
            uint256 minAmount = _getMinBidAmountForAuction(auction.amount, auction.minPercentIncrementInBasisPoints);
            require(msg.value >= minAmount, "ProjectAuction: Bid amount too low");

            // Cache and update bidder state before a possible reentrancy (via the value transfer)
            uint256 originalAmount = auction.amount;
            address payable originalBidder = auction.bidder;
            auction.amount = msg.value;
            auction.bidder = payable(_msgSender());

            // When a bid outbids another, check to see if a time manager should apply.
            if (auction.endTime - block.timestamp < auction.extDurationMinutes * 1 minutes) {
                auction.endTime = block.timestamp + auction.extDurationMinutes * 1 minutes;
            }

            // Refund the previous bidder
            _refund(originalBidder, originalAmount);
            emit AuctionOutBid(originalBidder, originalAmount);
        }

        emit AuctionBidPlaced(auctionId, _msgSender(), msg.value, auction.endTime);
    }

    /**
     * @notice Once the countdown has expired for an auction, anyone can settle the auction.
     * This will mint the NFT to the highest bidder and distribute funds.
     */
    function finalizeAuction(uint256 auctionId) public nonReentrant whenNotPaused {
        Auction storage auction = auctions[auctionId];
        require(!auction.finalized, "ProjectAuction: Auction already settled");
        require(bytes(auction.tokenURI).length > 0, "ProjectAuction: Auction not found");
        require(auction.endTime < block.timestamp, "ProjectAuction: Auction still in progress");

        auction.finalized = true;

        if (auction.bidder != address(0)) {
            _sendETHToTreasury(auction.amount);

            // mint nft to highest bidder
            uint256 tokenId = auction.project.managerMint(auction.bidder, auction.tokenURI);

            emit AuctionFinalized(auctionId, auction.bidder, auction.amount, address(auction.project), tokenId);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @notice set to true if whitelist or account info is needed for the auction
     */
    function setShouldVerifySignatureForBid(bool value) public onlyOwner {
        shouldVerifySignatureForBid = value;
        emit ShouldVerifySignatureUpdated(value);
    }

    /**
     * @notice Creates an auction for the given tokenURI.
     */
    function createAuction(Auction calldata auction) public onlyValidAuctionConfig(auction) onlyOwner {
        uint256 auctionId = _getNextAndIncrementAuctionId();
        auctions[auctionId] = auction;

        emit AuctionCreated(auctionId, auctions[auctionId]);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, the configuration
     * such as the minPrice may be changed by the owner.
     */
    function updateAuction(uint256 auctionId, Auction calldata newAuction)
        public
        onlyValidAuctionConfig(newAuction)
        onlyOwner
    {
        Auction storage auction = auctions[auctionId];
        require(bytes(auction.tokenURI).length > 0, "Auction not found");
        require(auction.startTime > block.timestamp, "Auction in progress");

        auctions[auctionId] = newAuction;

        emit AuctionUpdated(auctionId, newAuction);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, it may be canceled by the owner.
     */
    function cancelAuction(uint256 auctionId) public nonReentrant onlyOwner {
        Auction memory auction = auctions[auctionId];
        require(bytes(auction.tokenURI).length > 0, "Auction not found");
        require(auction.bidder == address(0), "Auction in progress");

        delete auctions[auctionId];

        emit AuctionCanceled(auctionId);
    }

    /**
     * @notice Allows TR Lab to cancel an auction, refunding the bidder.
     * This should only be used for extreme cases such as DMCA takedown requests. The reason should always be provided.
     */
    function adminCancelAuction(uint256 auctionId, string memory reason) public onlyOwner {
        require(bytes(reason).length > 0, "Include a reason for this cancellation");
        Auction memory auction = auctions[auctionId];
        require(bytes(auction.tokenURI).length > 0, "Auction not found");

        delete auctions[auctionId];

        if (auction.bidder != address(0)) {
            _refund(auction.bidder, auction.amount);
        }

        emit AuctionCanceledByAdmin(auctionId, reason);
    }

    function _getNextAndIncrementAuctionId() internal returns (uint256) {
        return nextAuctionId++;
    }

    /// @dev pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @dev unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /* ========== INTERNAL AUXILIARY FUNCTIONS ========== */

    /**
     * @notice refund to original bidder
     */
    function _refund(address payable originalBidder, uint256 originalAmount) internal {
        _sendValueWithFallbackWithdrawWithLowGasLimit(originalBidder, originalAmount);
    }

    /**
     * @dev Determines the minimum bid amount when outbidding another user.
     */
    function _getMinBidAmountForAuction(uint256 currentBidAmount, uint256 minPercentIncrementInBasisPoints)
        private
        pure
        returns (uint256)
    {
        uint256 minIncrement = (currentBidAmount * minPercentIncrementInBasisPoints) / BASIS_POINTS;
        if (minIncrement == 0) {
            // The next bid must be at least 1 wei greater than the current.
            return currentBidAmount + 1;
        }
        return minIncrement + currentBidAmount;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}