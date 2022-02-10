// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./interfaces/IWETH9.sol";
import "./interfaces/IUniswapRouter03.sol";
import "./interfaces/IUniswapV3Factory.sol";
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

    address immutable swapFactory;
    address immutable swapRouter;
    address immutable WETH;
    address immutable ERC721Proxy;
    address immutable zeroExExchange;
    address public server;

    struct NftMetadata {
        string name;
        string symbol;
        string ipfsHash;
    }

    struct AuctionConfig {
        // Duration of an auction cycle
        uint128 cyclePeriod;
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
        uint96 currentAuctionCycleStartTime;
        uint128 currentAuctionCycle;
        bool isFinished;
        bool isFrozen;
        bool isFiltered;
        bool isVerified;
        uint256 totalAmountCollected;
    }

    struct AuctionRootState {
        string auctionName;
        address owner;
        AuctionConfig config;
        AuctionStatus status;
    }

    mapping(string => AuctionRootState) internal auctions;

    event AuctionInitialized(string auctionId);
    event GoldNFTDeployed(address indexed auctionOwner, string auctionId, address nftAddress);
    event CycleOpened(uint128 indexed cycle, string auctionId);
    event Claimed(address indexed winner, uint256 indexed tokenId, string auctionId, uint256 price);
    event FundsClaimed(string auctionId, uint256 paid, uint256 fee);
    event AuctionFrozen(string auctionId, bool newState);
    event AuctionFiltered(string auctionId, bool newState);
    event AuctionVerified(string auctionId, bool newState);

    constructor(
        address _weth,
        address _swapFactory,
        address _swapRouter,
        address _ERC721Proxy,
        address _zeroExExchange,
        address _server
    ) {
        WETH = _weth;
        swapFactory = _swapFactory;
        swapRouter = _swapRouter;
        ERC721Proxy = _ERC721Proxy;
        zeroExExchange = _zeroExExchange;
        server = _server;
    }

    /// @notice Creates an auction and deploys it's NFT contract. Mints the first NFT
    /// @dev InitializeAuction {id, auction_name, auction_config, metadata_args, auction_start_timestamp}
    /// @param _id The auction's id (usually a slugified version of it's name)
    /// @param _auctionName The auction's human-readable name
    /// @param _auctionConfig A struct containing cyclePeriod, numberOfCycles, minimumBidAmount, bidderTokenAddress, nftAddres
    /// @param _nftMetadata The metadata of the NFT to be auctioned
    /// @param _poolFeeTier The fee tier of the WETH - bidderToken pair on the configured Uniswap V3-based exchange
    /// @param _auctionStart The start time of the first auction cycle (if 0, the current time)
    function initializeAuction(
        string calldata _id,
        string calldata _auctionName,
        AuctionConfig calldata _auctionConfig,
        NftMetadata calldata _nftMetadata,
        uint24 _poolFeeTier,
        uint96 _auctionStart
    ) external {
        // Note: in the future, custom NFT addresses might be accepted. This contract will need to have priviliges to mint it.
        // However, additional logic is required to handle those cases
        require(_auctionConfig.nftAddress == address(0), "No custom NFT support yet");
        require(auctions[_id].owner == address(0), "Auction ID already taken");

        // Currently only those tokens are supported, which have a direct pair with WETH on the configured Uniswap V3-based exchange
        if (_auctionConfig.bidderTokenAddress != WETH)
            require(
                IUniswapV3Factory(swapFactory).getPool(WETH, _auctionConfig.bidderTokenAddress, _poolFeeTier) !=
                    address(0),
                "WETH - token pool not found"
            );

        auctions[_id].auctionName = _auctionName;
        auctions[_id].owner = msg.sender;
        auctions[_id].config = _auctionConfig;
        auctions[_id].status.currentAuctionCycleStartTime = _auctionStart == 0
            ? uint96(block.timestamp)
            : _auctionStart;

        address nftAddress = address(
            new GoldNFT(_nftMetadata.name, _nftMetadata.symbol, _nftMetadata.ipfsHash, _auctionConfig.numberOfCycles)
        );
        auctions[_id].config.nftAddress = nftAddress;
        emit GoldNFTDeployed(msg.sender, _id, nftAddress);

        GoldNFT(nftAddress).safeMint(address(this));

        IERC20(_auctionConfig.bidderTokenAddress).approve(swapRouter, uint256(int256(-1)));

        emit AuctionInitialized(_id);
    }

    /// @notice Exchanges tokens for the latest NFT in the contract via the 0x protocol. Mints the next one, too
    /// @dev CloseAuctionCycle { id }
    /// @param _order A 0x V3 order with the caller as the maker and the 0 address as the taker
    /// @param _signature The order signed with 0x's utils
    /// @param _auctionId The id of the auction where the bid was placed
    function closeAuctionCycle(
        IZeroExExchange.Order calldata _order,
        bytes memory _signature,
        string calldata _auctionId
    ) external payable {
        require(msg.sender == server, "Only server wallet");
        require(auctions[_auctionId].owner != address(0), "Auction doesn't exist");

        // Validations
        AuctionConfig storage auctionConfig = auctions[_auctionId].config;
        AuctionStatus storage auctionStatus = auctions[_auctionId].status;
        require(auctionConfig.minimumBidAmount <= _order.makerAssetAmount, "Bid too low");
        require(
            auctionStatus.currentAuctionCycleStartTime + auctionConfig.cyclePeriod <= block.timestamp,
            "Auction cycle did not end yet"
        );
        require(!auctionStatus.isFinished, "Auction is finished");
        require(!auctionStatus.isFrozen, "Auction is frozen");

        address bidderTokenAddress = _order.makerAssetData.decodeERC20();
        require(bidderTokenAddress == auctionConfig.bidderTokenAddress, "Bid with an incorrect token");

        (address nftAddress, uint256 nftId) = _order.takerAssetData.decodeERC721();
        require(nftAddress == auctionConfig.nftAddress, "Bid for a different NFT address");
        require(nftId == auctionStatus.currentAuctionCycle, "Bid for a different NFT id");

        // Update collected amount
        auctionStatus.totalAmountCollected += _order.makerAssetAmount;

        // Token transfers
        GoldNFT(nftAddress).approve(ERC721Proxy, nftId);
        uint256 zeroExProtocolFee = tx.gasprice * IZeroExExchange(zeroExExchange).protocolFeeMultiplier();
        IZeroExExchange(zeroExExchange).fillOrder{value: zeroExProtocolFee}(
            _order,
            _order.takerAssetAmount,
            _signature
        );

        // Send the whole ETH balance to the owner since there's no way ETH is used in the contract
        payable(msg.sender).sendEther(address(this).balance);

        // Update auction status for the next cycle, mint the next token
        uint128 nextCycle = uint128(nftId) + 1; // nftId is equal to the current cycle, but it's cheaper to read it
        if (nextCycle < auctionConfig.numberOfCycles) {
            auctionStatus.currentAuctionCycle = nextCycle;
            auctionStatus.currentAuctionCycleStartTime = uint96(block.timestamp);
            GoldNFT(nftAddress).safeMint(address(this));
            emit CycleOpened(nextCycle, _auctionId);
        } else auctionStatus.isFinished = true;

        emit Claimed(_order.makerAddress, nftId, _auctionId, _order.makerAssetAmount);
    }

    /// @notice Claims tokens from treasury. Callable by auction owner. Also sends a 5% fee to the owner
    /// @dev ClaimFunds { id, amount }
    /// @param _auctionId The id of the auction which the accumulated funds belong to
    /// @param _amount The amount of funds to claim
    /// @param _uniFee The fee tier of the bidderToken - WETH pair (ignored if bidderToken == WETH)
    function claimFunds(
        string calldata _auctionId,
        uint256 _amount,
        uint24 _uniFee
    ) external {
        require(msg.sender == auctions[_auctionId].owner, "Only auction owner");
        auctions[_auctionId].status.totalAmountCollected -= _amount; // Reverts on underflow
        uint256 goldFee = _amount / 20;
        uint256 amountToPay = _amount - goldFee;
        address token = auctions[_auctionId].config.bidderTokenAddress;
        IERC20(token).transfer(msg.sender, amountToPay);
        if (token != WETH) {
            goldFee = IUniswapRouter03(swapRouter).exactInputSingle(
                IUniswapRouter03.ExactInputSingleParams({
                    tokenIn: token,
                    tokenOut: WETH,
                    fee: _uniFee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: goldFee,
                    amountOutMinimum: 1,
                    sqrtPriceLimitX96: 0
                })
            );
        }
        IWETH9(WETH).withdraw(goldFee);
        payable(owner()).sendEther(goldFee);
        emit FundsClaimed(_auctionId, amountToPay, goldFee);
    }

    /// @notice Freezes/unfreezes an auction
    /// @dev Freeze { id }
    /// @param _auctionId The id of the auction to freeze
    function changeAuctionFreezeState(string calldata _auctionId) external {
        require(msg.sender == auctions[_auctionId].owner, "Only auction owner");
        bool newState = !auctions[_auctionId].status.isFrozen;
        auctions[_auctionId].status.isFrozen = newState;
        emit AuctionFrozen(_auctionId, newState);
    }

    /// @notice Changes the filtered state of an auction
    /// @dev FilterAuction { id, filter }
    /// @param _auctionId The id of the auction to filter
    function changeAuctionFilteredState(string calldata _auctionId) external onlyOwner {
        bool newState = !auctions[_auctionId].status.isFiltered;
        auctions[_auctionId].status.isFiltered = newState;
        emit AuctionFiltered(_auctionId, newState);
    }

    /// @notice Changes the verified state of an auction
    /// @dev VerifyAuction { id }
    /// @param _auctionId The id of the auction to verify
    function changeAuctionVerifiedState(string calldata _auctionId) external onlyOwner {
        bool newState = !auctions[_auctionId].status.isVerified;
        auctions[_auctionId].status.isVerified = newState;
        emit AuctionVerified(_auctionId, newState);
    }

    /// @notice Returns the auction's settings
    /// @param _auctionId The id of the queried auction
    /// @return auctionName The human-readable name of the auction
    /// @return owner The auction's owner
    /// @return cyclePeriod The length of a cycle in seconds
    /// @return numberOfCycles The total number of cycles the auction has
    /// @return minimumBidAmount The minimum amount of tokens for a bid
    /// @return bidderTokenAddress The token used for bidding
    /// @return nftAddress The address of the auctioned NFT
    function getAuctionConfig(string calldata _auctionId)
        external
        view
        returns (
            string memory auctionName,
            address owner,
            uint128 cyclePeriod,
            uint128 numberOfCycles,
            uint256 minimumBidAmount,
            address bidderTokenAddress,
            address nftAddress
        )
    {
        return (
            auctions[_auctionId].auctionName,
            auctions[_auctionId].owner,
            auctions[_auctionId].config.cyclePeriod,
            auctions[_auctionId].config.numberOfCycles,
            auctions[_auctionId].config.minimumBidAmount,
            auctions[_auctionId].config.bidderTokenAddress,
            auctions[_auctionId].config.nftAddress
        );
    }

    /// @notice Returns the auction's current status
    /// @param _auctionId The id of the queried auction
    /// @return currentAuctionCycleStartTime The unix timestamp in seconds, at which the current auction cycle started
    /// @return currentAuctionCycle The number of the current auction cycle
    /// @return isFinished Whether the auction is finished
    /// @return isFrozen Whether the auction is frozen
    /// @return isFiltered Whether the auction is filtered
    /// @return isVerified Whether the auction is verified
    /// @return totalAmountCollected The total amount of funds collected from the already closed cycles
    function getAuctionStatus(string calldata _auctionId)
        external
        view
        returns (
            uint96 currentAuctionCycleStartTime,
            uint128 currentAuctionCycle,
            bool isFinished,
            bool isFrozen,
            bool isFiltered,
            bool isVerified,
            uint256 totalAmountCollected
        )
    {
        return (
            auctions[_auctionId].status.currentAuctionCycleStartTime,
            auctions[_auctionId].status.currentAuctionCycle,
            auctions[_auctionId].status.isFinished,
            auctions[_auctionId].status.isFrozen,
            auctions[_auctionId].status.isFiltered,
            auctions[_auctionId].status.isVerified,
            auctions[_auctionId].status.totalAmountCollected
        );
    }

    /// @notice Needed to be able to receive ETH in case the 0x Exchange returns some
    receive() external payable {}
}