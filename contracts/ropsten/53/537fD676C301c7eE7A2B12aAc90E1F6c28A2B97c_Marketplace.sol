// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/ITrading.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IERC1155.sol";
import "./MarketplaceSignature.sol";
import "hardhat/console.sol";

/// @title Marketplace Contract
/// @notice Contract that implements all the functionality of the marketplace
/// @dev Use ERC1155, Auction and Trade contracts functions

contract Marketplace is AccessControlUpgradeable, MarketplaceSignature {
    bytes32 public constant SIGNER_MARKETPLACE_ROLE =
        keccak256("SIGNER_MARKETPLACE_ROLE");
    bytes32 public constant OWNER_MARKETPLACE_ROLE =
        keccak256("OWNER_MARKETPLACE_ROLE");
    bytes32 public constant ADMIN_MARKETPLACE_ROLE =
        keccak256("ADMIN_MARKETPLACE_ROLE");
    address payable public feeCollector;
    uint128 constant hundredPercent = 100000; //100 *1000
    uint128 public platformFee;
    uint128 public timeExtendingRange;
    uint128 public timeExtendingValue;
    uint128 public allowedEditingPeriodOnStart;
    uint128 public allowedEditingPeriodOnEnd;
    bool public locked;
    ITrading public tradingContract;
    IAuction public auctionContract;
    IERC1155 public nftToken;
    event AddTradeLot(
        uint256 lotId,
        address lotCreator,
        uint256 tokenId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    );
    event EditTradeLot(
        uint256 lotId,
        address lotCreator,
        uint256 tokenId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    );
    event BuyNFTFromLot(
        uint256 lotId,
        address lotCreator,
        address buyer,
        uint128 amount
    );
    event AddAuctionLot(
        uint256 auctionId,
        address auctionCreator,
        uint256 tokenId,
        uint256 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    );
    event EditAuctionLot(
        uint256 auctionId,
        uint256 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    );

    event Claim(uint256 auctionId);
    event AddBid(uint256 auctionId, address bidder, uint256 bid);
    event ChangePlatformFee(uint128 newPlatformFee);
    event DelTradeLot(uint256 lotId);
    event DelAuctionLot(uint256 auctionId);
    event ExtendAuctionLifeTime(uint256 auctionId, uint128 newEndTime);
    event SetTimeExtendingRange(uint256 newTimeExtendingRange);
    event SetTimeExtendingValue(uint256 newTimeExtendingValue);

    /// @dev Check if caller is contract owner

    modifier onlyOwner() {
        require(
            hasRole(OWNER_MARKETPLACE_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    /// @dev Check if caller is trade lot creator
    /// @param lotId id of lot

    modifier onlyTradeLotCreator(uint256 lotId) {
        require(
            tradingContract.getOwner(lotId) == msg.sender,
            "Caller is not an owner"
        );
        _;
    }

    /// @dev Check if caller is auction creator
    /// @param auctionId id of auction

    modifier onlyAuctionLotCreator(uint256 auctionId) {
        require(
            auctionContract.getOwner(auctionId) == msg.sender,
            "Caller is not an owner or auction is not exist"
        );
        _;
    }

    /// @dev Check if caller is marketplace admin

    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_MARKETPLACE_ROLE, msg.sender),
            "Caller is not admin"
        );
        _;
    }

    /// @notice Contract initialization
    /// @dev Sets main dependencies and constants
    /// @param _name marketplace contract name
    /// @param _version marketplace contract version
    /// @param _platformFee platform fee, where 1 percent equal value 1000
    /// @return true if initialization complete success

    function init(
        string memory _name,
        string memory _version,
        uint128 _platformFee
    ) external initializer returns (bool) {
        feeCollector = payable(msg.sender);
        locked = false;
        timeExtendingRange = 120;
        timeExtendingValue = 120;
        allowedEditingPeriodOnStart = 24 * 3600;
        allowedEditingPeriodOnEnd = 24 * 3600;
        __Signature_init(_name, _version);
        _setupRole(OWNER_MARKETPLACE_ROLE, msg.sender);
        _setRoleAdmin(OWNER_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        _setRoleAdmin(SIGNER_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        _setRoleAdmin(ADMIN_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        setPlatformFee(_platformFee);
        return true;
    }

    function changeLock() external onlyOwner {
        locked = !locked;
    }

    /// @notice Sets dependencies between contracts
    /// @dev Sets addresses of ERC1155, Auction and Trade contracts
    /// @dev Only owner can call this function
    /// @param _tradingContract address of trade contract
    /// @param _auctionContract address of auction contract
    /// @param _nftToken address of ERC1155 contract

    function setDependencies(
        address _tradingContract,
        address _auctionContract,
        address _nftToken
    ) external onlyOwner {
        tradingContract = ITrading(_tradingContract);
        auctionContract = IAuction(_auctionContract);
        nftToken = IERC1155(_nftToken);
    }

    /// @notice Sets platform fee
    /// @dev Sets fee, in percent, where 1 percent equal value 1000, that marketplace receive after every sell
    /// @dev Only owner can call this function
    /// @param newPlatformFee new fee value. Max 50 000

    function setPlatformFee(uint128 newPlatformFee) public onlyOwner {
        require(
            newPlatformFee <= hundredPercent / 2,
            "Limit of platform fee amount"
        );
        platformFee = newPlatformFee;
        emit ChangePlatformFee(newPlatformFee);
    }

    // function setAllowedEditingPeriodOnStart(uint128 newValue)
    //     external
    //     onlyOwner
    // {
    //     allowedEditingPeriodOnStart = newValue;
    // }

    /// @notice Sets time extending range
    /// @dev Sets time period before auction end, in ms, in those every bid extend auction end time
    /// @dev Only owner can call this function
    /// @param newTimeExtendingRange new time extending range in ms

    function setTimeExtendingRange(uint128 newTimeExtendingRange)
        external
        onlyOwner
    {
        timeExtendingRange = newTimeExtendingRange;
        emit SetTimeExtendingRange(newTimeExtendingRange);
    }

    /// @notice Sets time extending value
    /// @dev Sets the value by which the auction end time is increased after each bid in time extending range
    /// @dev Only owner can call this function
    /// @param newTimeExtendingValue new time extending value in ms

    function setTimeExtendingValue(uint128 newTimeExtendingValue)
        external
        onlyOwner
    {
        timeExtendingValue = newTimeExtendingValue;
        emit SetTimeExtendingValue(newTimeExtendingValue);
    }

    /// @notice Sets fee collector
    /// @dev Sets address, that should receive all dividends
    /// @dev Only owner can call this function
    /// @param newFeeCollector address of new fee collector

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        feeCollector = payable(newFeeCollector);
    }

    function withdraw(address to, uint256 amount) private {
        require(!locked, "Reentrant call detected!");
        locked = true;
        (bool success, ) = to.call{value: amount}("");
        require(success, "Transfer failed.");
        locked = false;
    }

    /// @notice Collect fee and pay
    /// @dev Collect fee and pay profit to seller
    /// @param value total amount of funds, before fee collected
    /// @param tokenId id of token, that was sold
    /// @param value address of auction/trade lot creator

    function collectFeeAndPay(
        uint256 value,
        uint256 tokenId,
        address creator
    ) private {
        uint256 fees = (value * uint256(platformFee)) / uint256(hundredPercent);
        withdraw(feeCollector, fees);
        (address receiver, uint256 royaltyAmount) = nftToken.royaltyInfo(
            tokenId,
            value
        );
        if (receiver != creator && royaltyAmount != 0) {
            fees += royaltyAmount;
            withdraw(receiver, royaltyAmount);
        }
        withdraw(creator, value - fees);
    }

    /// @notice Transfer and unlock
    /// @dev Unlock tokens after it sold and transfer it to buyer
    /// @param from total amount of funds, before fee collected
    /// @param to id of token, that was sold
    /// @param tokenId id of token, that was sold
    /// @param amount address of auction/trade lot creator

    function transferAndUnlock(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) private {
        nftToken.unlockTokens(from, tokenId, amount);
        nftToken.safeTransferFrom(from, to, tokenId, amount, "");
    }

    /// @notice Returns full information about auction
    /// @dev Returns auction lot object by id with all params
    /// @param auctionId id of auction
    /// @return auctionLot auction object with all contains params

    function getAuctionInfo(uint256 auctionId)
        external
        view
        returns (IAuction.AuctionLot memory auctionLot)
    {
        return auctionContract.getAuctionInfo(auctionId);
    }

    /// @notice Return full information about trade lot
    /// @dev Returns lot object by lot id
    /// @param lotId id of lot
    /// @return lot lot object with all contains params

    function getLotById(uint256 lotId)
        external
        view
        returns (ITrading.TradeLot memory lot)
    {
        lot = tradingContract.getLotById(lotId);
    }

    /// @notice Creates new auction
    /// @dev Creates new auction entity in mapping
    /// @param tokenId id of tokens, that use in this lot
    /// @param amount amount of tokens, that will sell in auction
    /// @param startPrice minimal price for first bid
    /// @param startTime timestamp when auction start
    /// @param endTime timestamp when auction end
    /// @param minDelta minimum difference between the past and the current bid

    function addAuctionLot(
        uint256 tokenId,
        uint128 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(
            nftToken.isApprovedForAll(msg.sender, address(this)),
            "Token is not approved"
        );
        require(
            (nftToken.balanceOf(msg.sender, tokenId) -
                nftToken.getLockedTokensValue(msg.sender, tokenId)) >= amount,
            "Caller doesn`t have enough accessible token`s"
        );
        require(
            nftToken.isCreator(msg.sender, tokenId),
            "Only NFT creator can start auction"
        );
        require(
            block.timestamp <= endTime && endTime > startTime,
            "Wrong auction ending date"
        );
        require(amount > 0, "Amount should be positive");
        require(
            hasRole(
                SIGNER_MARKETPLACE_ROLE,
                _getAuctionSigner(
                    msg.sender,
                    tokenId,
                    amount,
                    startPrice,
                    startTime,
                    endTime,
                    minDelta,
                    v,
                    r,
                    s
                )
            ),
            "SignedAdmin should sign tokenId"
        );
        nftToken.lock(msg.sender, tokenId, amount);
        uint256 auctionId = auctionContract.addAuctionLot(
            msg.sender,
            tokenId,
            amount,
            startPrice,
            startTime,
            endTime,
            minDelta
        );
        emit AddAuctionLot(
            auctionId,
            msg.sender,
            tokenId,
            amount,
            startPrice,
            startTime,
            endTime,
            minDelta
        );
    }

    /// @notice Edit auction
    /// @dev Possible to edit only: amount, startPrice, startTime, endTime, minDelta
    /// @dev If some of params are will not change, should give them their previous value
    /// @dev Calls only by auction creator. Impossible to edit auction, if it already have bid
    /// @param auctionId id of auction
    /// @param amount new or previous amount value
    /// @param startPrice new or previous startPrice value
    /// @param startTime new or previous startTime value
    /// @param endTime new or previous endTime value
    /// @param minDelta new or previous minDelta value

    function editAuctionLot(
        uint256 auctionId,
        uint256 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    ) external onlyAuctionLotCreator(auctionId) {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(
            auction.lastBidder == address(0),
            "Impossible edit lot, if it is already have bids"
        );
        require(
            nftToken.isApprovedForAll(msg.sender, address(this)),
            "Token is not approved"
        );
        require(
            auction.endTime > block.timestamp,
            "Auction is already finished"
        );
        // require(
        //     auction.startTime + allowedEditingPeriodOnStart > block.timestamp ||
        //         block.timestamp + allowedEditingPeriodOnEnd > auction.endTime,
        //     "Impossible to edit auction now"
        // );
        require(startTime > block.timestamp, "Expired start time");
        require(endTime > block.timestamp, "Expired end time");
        require(
            endTime > startTime,
            "End time should be bigger than start time"
        );
        require(amount > 0, "Amount must be bigger that zero");
        require(
            nftToken.balanceOf(msg.sender, auction.tokenId) -
                nftToken.getLockedTokensValue(msg.sender, auction.tokenId) +
                auction.amount >=
                amount,
            "Caller doesn`t have enough accessible token`s"
        );
        auctionContract.editAuctionLot(
            auctionId,
            amount,
            startPrice,
            startTime,
            endTime,
            minDelta
        );
        if (amount > auction.amount) {
            nftToken.lock(
                auction.auctionCreator,
                auction.tokenId,
                amount - auction.amount
            );
        } else if (amount < auction.amount) {
            nftToken.unlockTokens(
                auction.auctionCreator,
                auction.tokenId,
                auction.amount - amount
            );
        }
        emit EditAuctionLot(
            auctionId,
            amount,
            startPrice,
            startTime,
            endTime,
            minDelta
        );
    }

    /// @notice Delete auction from contract
    /// @dev Removes entity by id from mapping
    /// @dev Calls only by auction creator. Impossible to delete auction, if it already have bid
    /// @param auctionId id of auction, that should delete

    function delAuctionLot(uint256 auctionId)
        external
        onlyAuctionLotCreator(auctionId)
    {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(
            auction.lastBidder == address(0),
            "Impossible delete lot, if it is already have bids"
        );
        // require(
        //     auction.startTime + allowedEditingPeriodOnStart > block.timestamp ||
        //         block.timestamp > auction.endTime,
        //     "Impossible to delete auction now"
        // );
        nftToken.unlockTokens(
            auction.auctionCreator,
            auction.tokenId,
            auction.amount
        );
        auctionContract.delAuctionLot(auctionId);
        emit DelAuctionLot(auctionId);
    }

    /// @notice Delete auction from contract
    /// @dev Removes entity by id from mapping
    /// @dev Calls only by auction creator. Impossible to delete auction, if it already have bid
    /// @param auctionId id of auction, that should delete

    function addBid(uint256 auctionId) external payable {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(auction.auctionCreator != address(0), "Auction is not exist");
        require(
            block.timestamp <= auction.endTime,
            "Auction is already finished"
        );
        require(
            auction.auctionCreator != msg.sender,
            "Creator cannot participate in own auction"
        );
        if (auction.lastBid == 0) {
            require(
                auction.startPrice != 0
                    ? msg.value >= auction.startPrice
                    : msg.value > 0,
                "Bid is lower than start price"
            );
        } else {
            require(
                auction.minDelta == 0
                    ? msg.value > auction.lastBid
                    : msg.value >= auction.lastBid + auction.minDelta,
                "Bid amount is wrong"
            );
        }
        require(
            msg.sender != auction.auctionCreator,
            "Creator can`t place bid"
        );
        auctionContract.addBid(auctionId, msg.value, msg.sender);
        withdraw(auction.lastBidder, auction.lastBid);
        if (block.timestamp + timeExtendingRange > auction.endTime) {
            auctionContract.extendActionLifeTime(auctionId, timeExtendingValue);
            emit ExtendAuctionLifeTime(
                auctionId,
                auction.endTime + timeExtendingValue
            );
        }
        emit AddBid(auctionId, msg.sender, msg.value);
    }

    /// @notice Cancel auction
    /// @dev Calls only by admin and only if auction has already ended.
    /// @dev This function return money to bidder and token to auction creator
    /// @param auctionId id of auction, that should delete
    /// @param v sign v value
    /// @param r sign r value
    /// @param s sign s value

    function cancelAuction(
        uint256 auctionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(auction.auctionCreator != address(0), "Auction is not exist");
        require(
            auction.lastBidder == msg.sender,
            "Caller is not winner of this auction"
        );
        require(
            block.timestamp > auction.endTime,
            "Auction is not finished now"
        );
        require(
            hasRole(
                ADMIN_MARKETPLACE_ROLE,
                _getAuctionCancelSigner(msg.sender, auctionId, v, r, s)
            ),
            "Admin should sign this action"
        );
        nftToken.unlockTokens(
            auction.auctionCreator,
            auction.tokenId,
            auction.amount
        );
        withdraw(auction.lastBidder, auction.lastBid);
        auctionContract.delAuctionLot(auctionId);
        emit DelAuctionLot(auctionId);
    }

    /// @notice Claim auction
    /// @dev Calls by any user, only if auction has already ended.
    /// @dev This function transfer profit to auction creator and token to last bidder
    /// @param auctionId id of auction, that should delete

    function claimAuction(uint256 auctionId) external {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(
            nftToken.isApprovedForAll(auction.auctionCreator, address(this)),
            "Token is not approved"
        );
        require(block.timestamp > auction.endTime, "Auction is not finished");
        require(
            auction.lastBidder != address(0),
            "Impossible claim auction with zero bidders"
        );
        collectFeeAndPay(
            auction.lastBid,
            auction.tokenId,
            auction.auctionCreator
        );
        transferAndUnlock(
            auction.auctionCreator,
            auction.lastBidder,
            auction.tokenId,
            auction.amount
        );
        auctionContract.delAuctionLot(auctionId);
        emit Claim(auctionId);
        emit DelAuctionLot(auctionId);
    }

    /// @notice Adds trade lot
    /// @dev Adds trade object in mapping at contract
    /// @param tokenId id of token in lot
    /// @param price price for single token in lot
    /// @param amount amount of tokens in current lot
    /// @param endTime timestamp when auction end
    /// @param v sign v value
    /// @param r sign r value
    /// @param s sign s value

    function addTradeLot(
        uint256 tokenId,
        uint256 price,
        uint128 amount,
        uint128 endTime,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(
            nftToken.isApprovedForAll(msg.sender, address(this)),
            "Token is not approved"
        );
        require(amount > 0, "Amount should be positive");
        require(price > 0, "Price should be positive");
        require(
            nftToken.balanceOf(msg.sender, tokenId) -
                nftToken.getLockedTokensValue(msg.sender, tokenId) >=
                amount,
            "Caller doesn`t have enough accessible token`s"
        );
        require(
            block.timestamp >= endTime || endTime == 0,
            "Wrong lot ending date"
        );
        require(
            hasRole(
                SIGNER_MARKETPLACE_ROLE,
                _getTradeSigner(
                    msg.sender,
                    tokenId,
                    price,
                    amount,
                    endTime,
                    v,
                    r,
                    s
                )
            ),
            "SignedAdmin should sign tokenId"
        );

        uint256 lotId = tradingContract.addTradeLot(
            msg.sender,
            tokenId,
            price,
            amount,
            endTime
        );
        nftToken.lock(msg.sender, tokenId, amount);
        emit AddTradeLot(lotId, msg.sender, tokenId, price, amount, endTime);
    }

    /// @notice Edit trade lot
    /// @dev Possible edit only price, amount, endTime
    /// @dev Calls only by lot creator
    /// @dev If some of params are will not change, should give them their previous value
    /// @param lotId id of lot
    /// @param price new or previous amount value
    /// @param amount new or previous startPrice value
    /// @param endTime new or previous startPrice value

    function editTradeLot(
        uint256 lotId,
        uint256 price,
        uint128 amount,
        uint128 endTime
    ) external onlyTradeLotCreator(lotId) {
        ITrading.TradeLot memory lot = tradingContract.getLotById(lotId);
        uint256 lockedTokens = nftToken.getLockedTokensValue(
            msg.sender,
            lot.tokenId
        );
        require(
            block.timestamp >= endTime || endTime == 0,
            "Wrong lot ending date"
        );
        require(amount > 0, "Amount should be positive");
        require(price > 0, "Price should be positive");
        require(
            nftToken.balanceOf(msg.sender, lot.tokenId) >= amount,
            "Caller doesn`t have enough accessible token`s"
        );
        if (lockedTokens > amount) {
            nftToken.unlockTokens(
                msg.sender,
                lot.tokenId,
                lockedTokens - amount
            );
        } else nftToken.lock(msg.sender, lot.tokenId, amount - lockedTokens);
        tradingContract.editTradeLot(lotId, price, amount, endTime);
        emit EditTradeLot(
            lotId,
            msg.sender,
            lot.tokenId,
            price,
            amount,
            endTime
        );
    }

    /// @notice Delete trade from contract
    /// @dev Calls only by lot creator
    /// @dev Remove trade object by id from mapping
    /// @param lotId id of trade lot, that should delete

    function delTradeLot(uint256 lotId) external onlyTradeLotCreator(lotId) {
        ITrading.TradeLot memory lot = tradingContract.getLotById(lotId);
        nftToken.unlockTokens(msg.sender, lot.tokenId, lot.amount);
        tradingContract.delTradeLot(lotId);
        emit DelTradeLot(lotId);
    }

    /// @notice Buy NFT
    /// @dev Message value should be equal amount multiplied price
    /// @dev Transfers token(s) to caller and transfers profit to lot creator
    /// @param lotId id of trade lot, that caller want to buy
    /// @param amount amount of trade lot,  that caller want to buy

    function buyNFTFromLot(uint256 lotId, uint128 amount) external payable {
        ITrading.TradeLot memory lot = tradingContract.getLotById(lotId);
        require(
            block.timestamp <= lot.endTime || lot.endTime == 0,
            "Wrong lot ending date"
        );
        require(lot.lotCreator != address(0), "Lot is not found");
        require(
            tradingContract.getOwner(lotId) != msg.sender,
            "Owner can not buy tokens by himself"
        );
        require(amount > 0, "Amount should be positive");
        require(
            amount * lot.price == msg.value,
            "The wrong amount of funds was transferred"
        );
        require(
            amount <= lot.amount,
            "Can not buy more tokens that accessible in lot "
        );
        transferAndUnlock(lot.lotCreator, msg.sender, lot.tokenId, amount);
        collectFeeAndPay(msg.value, lot.tokenId, lot.lotCreator);
        tradingContract.changeAmount(lotId, lot.amount - amount);
        emit BuyNFTFromLot(lotId, lot.lotCreator, msg.sender, amount);
        if (lot.amount - amount == 0) {
            tradingContract.delTradeLot(lotId);
            emit DelTradeLot(lotId);
        }
    }
}