// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interfaces/IZeroExExchange.sol";
import "./lib/LibAddress.sol";
import "./lib/LibZeroExAssetDecoder.sol";
import "./GoldNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @title Fundraising contract with a twist
contract Gold is Ownable, ERC721Holder {
    using LibAddress for address payable;
    using LibZeroExAssetDecoder for bytes;

    address immutable ERC721Proxy;
    address immutable zeroExExchange;

    struct AuctionConfig {
        // Duration of an auction cycle
        uint128 cyclePeriod;
        // Duration of the last bid required to complete the auction
        // uint128 encorePeriod;
        // Number of cycles
        uint128 numberOfCycles;
        // Minimum bid accepted
        uint256 minimumBidAmount;
        // The token that's used for bids
        address bidderTokenAddress;
        // The NFT that's being bid on
        address nftAddress;
    }

    struct AuctionStatus {
        uint112 currentAuctionStartTime;
        uint128 currentAuctionCycle;
        bool isFrozen;
        bool isActive;
        uint256 totalAmountCollected;
    }

    struct AuctionRootState {
        string auctionName;
        address owner;
        AuctionConfig config;
        AuctionStatus status;
    }

    mapping(string => AuctionRootState) auctions;

    event AuctionInitialized(string _id);
    event GoldNFTDeployed(address indexed auctionOwner, address nftAddress);
    event Claimed(address indexed winner, address indexed nftAddress, uint256 indexed tokenId);

    constructor(address _ERC721Proxy, address _zeroExExchange) {
        ERC721Proxy = _ERC721Proxy;
        zeroExExchange = _zeroExExchange;
    }

    /// @notice Creates an auction and deploys it's NFT contract. Mints the first NFT
    /// @dev InitializeAuction {id, auction_name, auction_config, metadata_args, auction_start_timestamp}
    function initializeAuction(
        string calldata _id,
        string calldata _auctionName,
        AuctionConfig calldata _auctionConfig,
        string calldata _nftName,
        string calldata _nftSymbol,
        uint112 _auctionStart
    ) external {
        // Note: in the future, custom NFT addresses might be accepted. This contract will need to have priviliges to mint it.
        // However, additional logic is required to handle those cases
        require(_auctionConfig.nftAddress == address(0), "No custom NFT support yet");

        // auctions[_id] = AuctionRootState({
        //     auctionName: _auctionName,
        //     owner: msg.sender,
        //     config: _auctionConfig,
        //     status: AuctionStatus({
        //         currentAuctionStartTime: _auctionStart == 0 ? uint128(block.timestamp) : _auctionStart,
        //         currentAuctionCycle: 0,
        //         isFrozen: false,
        //         isActive: true
        //     })
        // });
        auctions[_id].auctionName = _auctionName;
        auctions[_id].owner = msg.sender;
        auctions[_id].config = _auctionConfig;
        auctions[_id].status.currentAuctionStartTime = _auctionStart == 0 ? uint112(block.timestamp) : _auctionStart;
        auctions[_id].status.isActive = true;

        address nftAddress = address(new GoldNFT(_nftName, _nftSymbol));
        auctions[_id].config.nftAddress = nftAddress;
        emit GoldNFTDeployed(msg.sender, nftAddress);

        GoldNFT(nftAddress).safeMint(address(this));

        emit AuctionInitialized(_id);
    }

    /// @notice Exchanges tokens for the latest NFT in the contract via the 0x protocol. Mints the next one, too
    /// @dev CloseAuctionCycle { id }
    function closeAuctionCycle(
        IZeroExExchange.Order calldata _order,
        bytes memory _signature,
        string calldata _auctionId
    ) external payable {
        require(auctions[_auctionId].owner != address(0), "Auction doesn't exist");
        require(auctions[_auctionId].config.minimumBidAmount <= _order.makerAssetAmount, "Bid too low");

        AuctionStatus memory auctionStatus = auctions[_auctionId].status;
        require(auctionStatus.currentAuctionStartTime <= block.timestamp, "Auction is not open yet");
        require(auctionStatus.isActive, "Auction is not active");
        require(!auctionStatus.isFrozen, "Auction is frozen");

        address bidderTokenAddress = _order.makerAssetData.decodeERC20();
        require(bidderTokenAddress == auctions[_auctionId].config.bidderTokenAddress, "Bid with an incorrect token");

        (address nftAddress, uint256 nftId) = _order.takerAssetData.decodeERC721();
        require(nftAddress == auctions[_auctionId].config.nftAddress, "Bid for a different NFT address");
        require(nftId == auctionStatus.currentAuctionCycle, "Bid for a different NFT id");

        auctions[_auctionId].status.totalAmountCollected += _order.makerAssetAmount;

        GoldNFT(nftAddress).approve(ERC721Proxy, nftId);
        IZeroExExchange.FillResults memory results = IZeroExExchange(zeroExExchange).fillOrder{value: msg.value}(
            _order,
            _order.takerAssetAmount,
            _signature
        );
        payable(msg.sender).sendEther(msg.value - results.protocolFeePaid);

        GoldNFT(nftAddress).safeMint(address(this));

        emit Claimed(_order.makerAddress, nftAddress, nftId);
    }

    /// @notice Claims tokens from treasury. Callable by auction owner. Also sends any fees to the admin
    /// @dev ClaimFunds { id, amount }
    function claimFunds(string calldata _auctionId, uint256 _amount) external {
        require(msg.sender == auctions[_auctionId].owner, "Only auction owner");
        require(_amount <= auctions[_auctionId].status.totalAmountCollected, "Cannot withdraw that much");
        auctions[_auctionId].status.totalAmountCollected -= _amount;
        IERC20(auctions[_auctionId].config.bidderTokenAddress).transfer(msg.sender, _amount);
        // TODO: send fees to admin. For that, implement a fee mechanism in the first place
    }

    receive() external payable {}
}