// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

/** OpenZeppelin Dependencies */
import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import '../base/AuctionBase.sol';
import '../abstracts/ExternallyCallable.sol';

import '../libs/AxionSafeCast.sol';

contract Auction is IAuction, ExternallyCallable, AuctionBase {
    using AxionSafeCast for uint256;
    using SafeCastUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    //** Mapping */
    mapping(uint256 => Options) internal optionsOf;
    mapping(uint256 => AuctionReserves) internal reservesOf;
    mapping(address => EnumerableSetUpgradeable.UintSet) internal auctionsOf;
    mapping(uint256 => mapping(address => UserBid)) internal auctionBidOf;

    Settings internal settings;
    Addresses internal addresses;
    Contracts internal contracts;
    AuctionData[7] internal auctions; // 7 values for 7 days of the week

    /* UPGRADEABILITY: New variables must go below here. */

    /** Update Price of current auction
        Get current axion day
        Get uniswapLastPrice
        Set middlePrice
     */
    function _updatePrice(uint256 currentAuctionId) internal {
        /** Set reserves of */
        reservesOf[currentAuctionId].uniswapLastPrice = (getUniswapLastPrice() / 1e12).toUint64(); // div by 1e12 as in memory it's 18 dps and we store 6

        if (optionsOf[currentAuctionId].middlePriceDays == 1) {
            reservesOf[currentAuctionId].uniswapMiddlePrice = reservesOf[currentAuctionId]
                .uniswapLastPrice;
        } else {
            reservesOf[currentAuctionId].uniswapMiddlePrice = (getUniswapMiddlePriceForDays(
                currentAuctionId
            ) / 1e12)
                .toUint64();
        }
    }

    /**
        Bid- Set values for bid
     */
    function bid(
        address bidder,
        address ref,
        uint256 eth
    ) external override onlyExternalCaller returns (uint256) {
        uint256 currentAuctionId = getCurrentAuctionId();

        _saveAuctionData(currentAuctionId);
        _updatePrice(currentAuctionId);

        /** If referralsOn is true allow to set ref */
        if (optionsOf[currentAuctionId].referralsOn == true) {
            auctionBidOf[currentAuctionId][bidder].ref = ref;
        }

        /** Set auctionBid for bidder */
        auctionBidOf[currentAuctionId][bidder].eth += eth.toUint96();

        auctionsOf[bidder].add(currentAuctionId);

        reservesOf[currentAuctionId].eth += (eth / 1e12).toUint48();

        return currentAuctionId;
    }

    /**
        getUniswapLastPrice - Use uniswap router to determine current price of AXN per ETH
    */
    function getUniswapLastPrice() internal view returns (uint256) {
        address[] memory path = new address[](2);

        path[0] = contracts.uniswapRouter.WETH();
        path[1] = addresses.token;

        uint256 price = contracts.uniswapRouter.getAmountsOut(1e18, path)[1];

        return price;
    }

    /**
        getUniswapMiddlePriceForDays
            Use the "last known price" for the last {middlePriceDays} days to determine middle price by taking an average
     */
    function getUniswapMiddlePriceForDays(uint256 currentAuctionId)
        internal
        view
        returns (uint256)
    {
        uint256 index = currentAuctionId;
        uint256 sum;
        uint256 points;

        while (points != optionsOf[currentAuctionId].middlePriceDays) {
            if (reservesOf[index].uniswapLastPrice != 0) {
                sum += uint256(reservesOf[index].uniswapLastPrice) * 1e12;
                points++;
            }

            if (index == 0) break;

            index--;
        }

        if (sum == 0) return getUniswapLastPrice();
        else return sum / points;
    }

    /**
        withdraw - Withdraws an auction bid and stakes axion in staking contract

        @param auctionId {uint256} - Auction to withdraw from
        @param stakeDays {uint256} - # of days to stake in portal
     */
    function withdraw(uint256 auctionId, uint256 stakeDays) external {
        /** Require # of staking days < 5556 */
        require(stakeDays <= 5555, 'AUCTION: stakeDays > 5555');

        /** Ensure auctionId of withdraw is not todays auction, and user bid has not been withdrawn and eth > 0 */
        require(getCurrentAuctionId() > auctionId, 'AUCTION: Auction is active');
        require(auctionBidOf[auctionId][msg.sender].eth != 0, 'AUCTION: Zero bid or withdrawn');
        // Require the # of days staking > options
        require(
            stakeDays >= optionsOf[auctionId].autoStakeDays,
            'AUCTION: stakeDays < minimum days'
        );

        /** Call common withdraw functions */
        withdrawInternal(
            auctionBidOf[auctionId][msg.sender].ref,
            auctionBidOf[auctionId][msg.sender].eth,
            auctionId,
            stakeDays
        );

        auctionBidOf[auctionId][msg.sender].eth = 0;
        auctionBidOf[auctionId][msg.sender].ref = address(0);
    }

    /**
        withdrawLegacy - Withdraws a legacy auction bid and stakes axion in staking contract

        @param auctionId {uint256} - Auction to withdraw from
        @param stakeDays {uint256} - # of days to stake in portal
     */
    function withdrawLegacy(uint256 auctionId, uint256 stakeDays) external {
        /** This stops a user from using withdrawLegacy twice, since the bid is put into memory at the end */
        require(
            auctionsOf[msg.sender].contains(auctionId) == false,
            'AUCTION: Already withdrawn or is v3.'
        );

        /** Ensure stake days > options  */
        require(
            stakeDays >= auctions[auctionId % 7].options.autoStakeDays,
            'AUCTION: stakeDays < minimum days'
        );

        require(stakeDays <= 5555, 'AUCTION: stakeDays > 5555');

        require(getCurrentAuctionId() > auctionId, 'AUCTION: Auction is active');

        (uint256 eth, address ref, bool withdrawn) =
            contracts.auctionV2.auctionBidOf(auctionId, msg.sender);

        require(eth != 0, 'AUCTION: empty bid');
        require(withdrawn == false, 'AUCTION: withdrawn in v2');

        /** Common withdraw functionality */
        withdrawInternal(ref, eth, auctionId, stakeDays);

        /** Bring v2 auction bid to v3 */
        auctionsOf[msg.sender].add(auctionId);
    }

    function withdrawInternal(
        address ref,
        uint256 bidAmount,
        uint256 auctionId,
        uint256 stakeDays
    ) internal {
        // Calculate payout for bidder

        uint256 tokensInReserve;
        uint256 ethInReserve;
        uint256 uniswapMiddlePrice;
        uint256 discountPercent;
        uint256 premiumPercent;

        if (auctionId <= settings.lastAuctionIdV2) {
            (ethInReserve, tokensInReserve, , uniswapMiddlePrice) = contracts.auctionV2.reservesOf(
                auctionId
            );

            uint256 day = auctionId % 7;

            discountPercent = auctions[day].options.discountPercent;
            premiumPercent = auctions[day].options.premiumPercent;
        } else {
            uniswapMiddlePrice = uint256(reservesOf[auctionId].uniswapMiddlePrice) * 1e12;
            tokensInReserve = uint256(reservesOf[auctionId].token) * 1e12;
            ethInReserve = uint256(reservesOf[auctionId].eth) * 1e12;
            discountPercent = uint256(optionsOf[auctionId].discountPercent);
            premiumPercent = uint256(optionsOf[auctionId].premiumPercent);
        }

        uint256 uniswapPayoutWithPercent =
            _calculatePayoutWithUniswap(
                uniswapMiddlePrice,
                bidAmount,
                (bidAmount * tokensInReserve) / ethInReserve,
                discountPercent,
                premiumPercent
            );

        /** If referrer is empty simple task */
        if (address(ref) == address(0)) {
            contracts.stakeMinter.externalStake(uniswapPayoutWithPercent, stakeDays, msg.sender);

            emit BidStake(
                msg.sender,
                uniswapPayoutWithPercent,
                auctionId,
                block.timestamp,
                stakeDays
            );
        } else {
            /** Determine referral amount */
            (uint256 toRefMintAmount, uint256 toUserMintAmount) =
                _calculateRefAndUserAmountsToMint(auctionId, uniswapPayoutWithPercent);

            /** Add referral % to payout */
            uniswapPayoutWithPercent += toUserMintAmount;

            /** Call external stake for referrer and bidder */
            contracts.stakeMinter.externalStake(uniswapPayoutWithPercent, stakeDays, msg.sender);

            /** We do not want to stake if the referral address is the dEaD address */
            if (address(ref) != address(0x000000000000000000000000000000000000dEaD)) {
                contracts.stakeMinter.externalStake(toRefMintAmount, 14, ref);
            }

            emit BidStake(
                msg.sender,
                uniswapPayoutWithPercent,
                auctionId,
                block.timestamp,
                stakeDays
            );
        }
    }

    /** External Contract Caller functions 
        @param amount {uint256} - amount to add to next dailyAuction
    */
    function addTokensToNextAuction(uint256 amount) external override onlyExternalCaller {
        // Adds a specified amount of axion to tomorrows auction
        reservesOf[getCurrentAuctionId() + 1].token += (amount / 1e12).toUint64();
    }

    /** Calculate functions */
    function calculateNearestWeeklyAuction() public view returns (uint256) {
        uint256 currentAuctionId = getCurrentAuctionId();
        return currentAuctionId + ((7 - currentAuctionId) % 7);
    }

    /** Get current day of week
     * EX: friday = 0, saturday = 1, sunday = 2 etc...
     */
    function getCurrentDay() internal view returns (uint256) {
        uint256 currentAuctionId = getCurrentAuctionId();
        return currentAuctionId % 7;
    }

    function getCurrentAuctionId() public view returns (uint256) {
        return (block.timestamp - settings.contractStartTimestamp) / settings.secondsInDay;
    }

    /** Determine payout and overage
        @param uniswapMiddlePrice {uint256}
        @param amount {uint256} - Amount to use to determine overage
        @param payout {uint256} - payout
        @param discountPercent {uint256}
        @param premiumPercent {uint256}
     */
    function _calculatePayoutWithUniswap(
        uint256 uniswapMiddlePrice,
        uint256 amount,
        uint256 payout,
        uint256 discountPercent,
        uint256 premiumPercent
    ) internal view returns (uint256) {
        // Get payout for user

        uint256 uniswapPayout = (uniswapMiddlePrice * amount) / 1e18;

        // Get payout with percentage based on discount, premium
        uint256 uniswapPayoutWithPercent =
            uniswapPayout +
                ((uniswapPayout * discountPercent) / 100) - // I dont think this is necessary
                ((uniswapPayout * premiumPercent) / 100);

        if (payout > uniswapPayoutWithPercent) {
            return uniswapPayoutWithPercent;
        } else {
            return payout;
        }
    }

    /** Determine amount of axion to mint for referrer based on amount
        @param amount {uint256} - amount of axion

        @return (uint256, uint256)
     */
    function _calculateRefAndUserAmountsToMint(uint256 auctionId, uint256 amount)
        private
        view
        returns (uint256, uint256)
    {
        uint256 toRefMintAmount = (amount * uint256(optionsOf[auctionId].referrerPercent)) / 100;
        uint256 toUserMintAmount = (amount * uint256(optionsOf[auctionId].referredPercent)) / 100;

        return (toRefMintAmount, toUserMintAmount);
    }

    /** Save auction data
        Determines if auction is over. If auction is over set lastAuctionId to currentAuctionId
    */
    function _saveAuctionData(uint256 currentAuctionId) internal {
        if (settings.lastAuctionId < currentAuctionId) {
            uint256 currentDay = getCurrentDay();

            reservesOf[currentAuctionId].filled = true;
            reservesOf[currentAuctionId].token += (uint256(auctions[currentDay].amountToFillBy) *
                1e6)
                .toUint64();

            optionsOf[currentAuctionId] = auctions[currentDay].options;

            // If last auction is undersold, roll to next weekly auction
            uint256 tokensSold =
                uint256(reservesOf[settings.lastAuctionId].eth) *
                    uint256(reservesOf[settings.lastAuctionId].uniswapMiddlePrice);

            tokensSold +=
                (((tokensSold * uint256(optionsOf[settings.lastAuctionId].discountPercent)) / 100) -
                    ((tokensSold * uint256(optionsOf[settings.lastAuctionId].premiumPercent)) /
                        100)) /
                1e6;

            if (tokensSold < reservesOf[settings.lastAuctionId].token) {
                reservesOf[calculateNearestWeeklyAuction()].token += (reservesOf[
                    settings.lastAuctionId
                ]
                    .token - tokensSold)
                    .toUint64();
            }

            emit AuctionIsOver(
                reservesOf[settings.lastAuctionId].eth,
                reservesOf[settings.lastAuctionId].token,
                settings.lastAuctionId
            );

            settings.lastAuctionId = currentAuctionId.toUint64();
        }
    }

    /** Public Setter Functions */
    function setReferrerPercentage(uint8 day, uint8 percent) external onlyManager {
        auctions[day].options.referrerPercent = percent;
    }

    function setReferredPercentage(uint8 day, uint8 percent) external onlyManager {
        auctions[day].options.referredPercent = percent;
    }

    function setReferralsOn(uint8 day, bool _referralsOn) external onlyManager {
        auctions[day].options.referralsOn = _referralsOn;
    }

    function setAutoStakeDays(uint8 day, uint16 _autoStakeDays) external onlyManager {
        auctions[day].options.autoStakeDays = _autoStakeDays;
    }

    function setDiscountPercent(uint8 day, uint8 percent) external onlyManager {
        auctions[day].options.discountPercent = percent;
    }

    function setPremiumPercent(uint8 day, uint8 percent) external onlyManager {
        auctions[day].options.premiumPercent = percent;
    }

    function setMiddlePriceDays(uint8 day, uint8 _middleDays) external onlyManager {
        auctions[day].options.middlePriceDays = _middleDays;
    }

    /** VCA Setters */
    /** @dev Set Auction Mode
        @param _day {uint8} 0 - 6 value. 0 represents Saturday, 6 Represents Friday
        @param _mode {uint8} 0 or 1. 1 VCA, 0 Normal
     */
    function setAuctionMode(uint8 _day, uint8 _mode) external onlyManager {
        auctions[_day].mode = _mode;
    }

    /** @dev Set Tokens of day
        @param day {uint8} 0 - 6 value. 0 represents Saturday, 6 Represents Friday
        @param coins {address[]} - Addresses to buy from uniswap
        @param percentages {uint8[]} - % of coin to buy, must add up to 100%
     */
    function setTokensOfDay(
        uint8 day,
        address[] calldata coins,
        uint8[] calldata percentages
    ) external onlyManager {
        AuctionData storage auction = auctions[day];

        auction.mode = 1;
        delete auction.tokens;

        uint8 percent = 0;
        for (uint8 i; i < coins.length; i++) {
            auction.tokens.push(VentureToken(coins[i], percentages[i]));
            percent += percentages[i];
            contracts.vcAuction.addDivToken(coins[i]);
        }

        require(percent == 100, 'AUCTION: Percentage for venture day must equal 100');
    }

    function setAuctionAmountToFillBy(uint8 day, uint128 amountToFillBy) external onlyManager {
        auctions[day].amountToFillBy = amountToFillBy;
    }

    /** Initialize */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        // Addresses
        address _mainToken,
        // Externally callable
        address _auctionBidder,
        address _nativeSwap,
        // Contracts
        address _stakeMinter,
        address _stakeBurner,
        address _auctionV2,
        address _vcAuction,
        address _uniswap
    ) external onlyMigrator {
        /** Roles */
        _setupRole(EXTERNAL_CALLER_ROLE, _auctionBidder);
        _setupRole(EXTERNAL_CALLER_ROLE, _nativeSwap);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeMinter);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeBurner);

        /** addresses */
        addresses.token = _mainToken;

        /** Contracts */
        contracts.auctionV2 = IAuctionV2(_auctionV2);
        contracts.vcAuction = IVCAuction(_vcAuction);
        contracts.stakeMinter = IStakeMinter(_stakeMinter);
        contracts.uniswapRouter = IUniswapV2Router02(_uniswap);
    }

    function restore(
        uint16 _autoStakeDays,
        uint8 _referrerPercent,
        uint8 _referredPercent,
        uint8 _discountPercent,
        uint8 _premiumPercent,
        uint8 _middlePriceDays,
        bool _referralsOn,
        uint64 _lastAuctionEventId,
        uint64 _lastAuctionEventIdV2,
        uint64 _contractStartTimestamp,
        uint64 _secondsInDay
    ) external onlyMigrator {
        for (uint256 i = 0; i < auctions.length; i++) {
            auctions[i].options.autoStakeDays = _autoStakeDays;
            auctions[i].options.referrerPercent = _referrerPercent;
            auctions[i].options.referredPercent = _referredPercent;
            auctions[i].options.discountPercent = _discountPercent;
            auctions[i].options.premiumPercent = _premiumPercent;
            auctions[i].options.middlePriceDays = _middlePriceDays;
            auctions[i].options.referralsOn = _referralsOn;
        }

        settings.lastAuctionId = _lastAuctionEventId;
        settings.lastAuctionIdV2 = _lastAuctionEventIdV2;
        settings.contractStartTimestamp = _contractStartTimestamp;
        settings.secondsInDay = _secondsInDay;
    }

    /** Getter functions */
    function getTodaysMode() external view override returns (uint256) {
        return auctions[getCurrentDay()].mode;
    }

    function getTodaysTokens() external view override returns (VentureToken[] memory) {
        return auctions[getCurrentDay()].tokens;
    }

    function getAuctionModes() external view returns (uint8[7] memory) {
        uint8[7] memory auctionModes;

        for (uint8 i; i < auctions.length; i++) {
            auctionModes[i] = auctions[i].mode;
        }

        return auctionModes;
    }

    function getAuctionDay(uint8 day) external view returns (AuctionData memory) {
        return auctions[day];
    }

    function getTokensOfDay(uint8 _day) external view returns (VentureToken[] memory) {
        return auctions[_day].tokens;
    }

    function getDefaultOptionsOfDay(uint8 day) external view returns (Options memory) {
        return auctions[day].options;
    }

    function getOptionsOf(uint256 auctionId) external view returns (Options memory) {
        return optionsOf[auctionId];
    }

    function getAuctionReservesOf(uint256 auctionId)
        external
        view
        returns (AuctionReserves memory)
    {
        return reservesOf[auctionId];
    }

    function getAuctionsOf(address bidder) external view returns (uint256[] memory) {
        uint256[] memory auctionsIds = new uint256[](auctionsOf[bidder].length());

        for (uint256 i = 0; i < auctionsOf[bidder].length(); i++) {
            auctionsIds[i] = auctionsOf[bidder].at(i);
        }

        return auctionsIds;
    }

    function getAuctionBidOf(uint256 auctionId, address bidder)
        external
        view
        returns (UserBid memory)
    {
        return auctionBidOf[auctionId][bidder];
    }

    function getSettings() external view returns (Settings memory) {
        return settings;
    }

    function getAuctionData() external view returns (AuctionData[7] memory) {
        return auctions;
    }
}