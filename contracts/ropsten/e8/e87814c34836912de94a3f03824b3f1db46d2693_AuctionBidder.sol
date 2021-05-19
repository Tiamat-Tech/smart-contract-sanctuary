// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/** OpenZeppelin Dependencies */
import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import './abstracts/Migrateable.sol';
import './abstracts/Manageable.sol';

import './libs/AxionSafeCast.sol';

import './interfaces/IAuction.sol';
import './interfaces/IVCAuction.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract AuctionBidder is Initializable, Migrateable, Manageable {
    using AxionSafeCast for uint256;
    using SafeCastUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    struct Settings {
        uint64 contractStartTimestamp; // Beginning of contract
        uint64 secondsInDay; // # of seconds per "axion day" (86400)
    }

    struct Contracts {
        IAuction auction;
        IVCAuction vcAuction;
        IUniswapV2Router02 uniswapRouter;
    }

    struct Addresses {
        address token;
        address stakeManager;
    }

    event Bid(address indexed account, uint256 value, uint256 indexed auctionId, uint256 time);

    event VentureBid(
        address indexed account,
        uint256 ethBid,
        uint256 indexed auctionId,
        uint256 time,
        address[] coins,
        uint256[] amountBought
    );

    Settings internal settings;
    Addresses internal addresses; // (See Address struct above)
    Contracts internal contracts;

    /**
        Get token paths
        Use uniswap to buy tokens back and send to staking platform using (addresses.staking)

        @param tokenAddress {address} - Token to buy from uniswap
        @param amountOutMin {uint256} - Slippage tolerance for router
        @param amount {uint256} - Min amount expected
        @param deadline {uint256} - Deadline for trade (used for uniswap router)
     */
    function _swapEthForToken(
        address tokenAddress,
        address recipientAddress,
        uint256 amountOutMin,
        uint256 amount,
        uint256 deadline
    ) private returns (uint256) {
        address[] memory path = new address[](2);

        path[0] = contracts.uniswapRouter.WETH(); // this should be persited into this contract as it costs to get from other contract
        path[1] = tokenAddress;

        return
            contracts.uniswapRouter.swapExactETHForTokens{value: amount}(
                amountOutMin,
                path,
                recipientAddress,
                deadline
            )[1];
    }

    /**
        Bid function which routes to either venture bid or bid internal

        @param amountOutMin {uint256[]} - Slippage tolerance for uniswap router 
        @param deadline {uint256} - Deadline for trade (used for uniswap router)
        @param ref {address} - Referrer Address to get % axion from bid
     */
    function bid(
        uint256[] calldata amountOutMin,
        uint256 deadline,
        address ref
    ) external payable {
        uint256 auctionMode = contracts.auction.getTodaysMode(); // Get from auction

        if (auctionMode == 0) {
            normalBid(amountOutMin[0], deadline, ref);
        } else if (auctionMode == 1) {
            ventureBid(amountOutMin, deadline);
        }
    }

    /**
        NormalBid - Buys back axion from uniswap router and sends to staking platform

        @param amountOutMin {uint256} - Slippage tolerance for uniswap router 
        @param deadline {uint256} - Deadline for trade (used for uniswap router)
        @param ref {address} - Referrer Address to get % axion from bid
     */
    function normalBid(
        uint256 amountOutMin,
        uint256 deadline,
        address ref
    ) internal {
        /** Can not refer self */
        require(msg.sender != ref, 'msg.sender == ref');

        // Get percentage for recipient and uniswap (Extra function really unnecessary)
        uint256 toUniswap = getUniswapAmountToSend();

        /** Buy back tokens from uniswap and send to staking contract */
        _swapEthForToken(
            addresses.token,
            addresses.stakeManager,
            amountOutMin,
            toUniswap,
            deadline
        );

        //** Run common shared functionality between VCA and Normal */
        uint256 auctionId = contracts.auction.bid{value: msg.value}(msg.sender, ref);

        /** Send event to blockchain */
        emit Bid(msg.sender, msg.value, auctionId, block.timestamp);
    }

    /**
        VentureBid - Buys back axion from uniswap router and sends to staking platform

        @param amountOutMin {uint256[]} - Slippage tolerance for uniswap router 
        @param deadline {uint256} - Deadline for trade (used for uniswap router)
     */
    function ventureBid(uint256[] memory amountOutMin, uint256 deadline) internal {
        /** Get the token(s) of the day */
        VentureToken[] memory tokens = contracts.auction.getTodaysTokens();
        /** Create array to determine amount bought for each token */
        address[] memory coinsBought = new address[](tokens.length);
        uint256[] memory amountsBought = new uint256[](tokens.length);

        /** Loop over tokens to purchase */
        for (uint8 i = 0; i < tokens.length; i++) {
            // Determine amount to purchase based on ethereum bid
            uint256 amountBought;
            uint256 amountToBuy = (msg.value * tokens[i].percentage) / 100;

            /** If token is 0xFFfFfF... we buy no token and just distribute the bidded ethereum */
            if (tokens[i].coin != address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)) {
                amountBought = _swapEthForToken(
                    tokens[i].coin,
                    address(contracts.vcAuction),
                    amountOutMin[i],
                    amountToBuy,
                    deadline
                );

                contracts.vcAuction.updateTokenPricePerShare(
                    payable(msg.sender),
                    tokens[i].coin,
                    amountBought
                );
            } else {
                amountBought = amountToBuy;

                contracts.vcAuction.updateTokenPricePerShare{value: amountToBuy}(
                    payable(msg.sender),
                    tokens[i].coin,
                    amountToBuy
                ); // Payable amount
            }

            coinsBought[i] = tokens[i].coin;
            amountsBought[i] = amountBought;
        }

        uint256 currentAuctionId = contracts.auction.bid{value: msg.value}(msg.sender, address(0));

        emit VentureBid(
            msg.sender,
            msg.value,
            currentAuctionId,
            block.timestamp,
            coinsBought,
            amountsBought
        );
    }

    /** Get Percentages for recipient and uniswap for ethereum bid Unnecessary function */
    function getUniswapAmountToSend() private returns (uint256) {
        uint256 forRecipient = (msg.value * 20) / 100; // stays in contract
        return msg.value - forRecipient;
    }

    /** Initialize */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _auction,
        address _vcAuction,
        address _uniswap,
        address _token,
        address _stakeManager,
        uint64 _contractStartTimestamp,
        uint64 _secondsInDay
    ) external onlyMigrator {
        contracts.auction = IAuction(_auction);
        contracts.vcAuction = IVCAuction(_vcAuction);
        contracts.uniswapRouter = IUniswapV2Router02(_uniswap);

        addresses.token = _token;
        addresses.stakeManager = _stakeManager;

        settings.contractStartTimestamp = _contractStartTimestamp;
        settings.secondsInDay = _secondsInDay;
    }

    function getSettings() external view returns (Settings memory) {
        return settings;
    }
}