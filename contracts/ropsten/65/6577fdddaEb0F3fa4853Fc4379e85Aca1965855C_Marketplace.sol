// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/ITrading.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IERC1155Implementation.sol";
import "./MarketplaceSignature.sol";
import "hardhat/console.sol";

contract Marketplace is AccessControlUpgradeable, MarketplaceSignature {
    bytes32 public constant SIGNER_MARKETPLACE_ROLE =
        keccak256("SIGNER_MARKETPLACE_ROLE");
    bytes32 public constant OWNER_MARKETPLACE_ROLE =
        keccak256("OWNER_MARKETPLACE_ROLE");
    bytes32 public constant ADMIN_MARKETPLACE_ROLE =
        keccak256("ADMIN_MARKETPLACE_ROLE");
    address payable public feeCollecter;
    uint128 constant hundredPercent = 100000; //100 *1000
    uint128 public platformFee;
    uint128 public timeExtendingRange;
    uint128 public timeExtendingValue;
    uint128 public allowedEditingPeriodOnStart;
    uint128 public allowedEditingPeriodOnEnd;
    ITrading public tradingContract;
    IAuction public auctionContract;
    IERC1155Implementation public nftToken;
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
        uint128 endTime,
        uint128 minDelta
    );
    event AddBid(uint256 auctionId, address bidder, uint256 bid);
    event ChangePlatformFee(uint128 newPlatformFee);
    event DelTradeLot(uint256 lotId);
    event DelAuctionLot(uint256 auctionId);
    event ExtendAuctionLifeTime(uint256 auctionId, uint128 newEndTime);

    function setPlatformFee(uint128 newPlatformFee) public onlyOwner {
        require(
            newPlatformFee <= hundredPercent,
            "Limit of platform fee amount"
        );
        platformFee = newPlatformFee;
        emit ChangePlatformFee(newPlatformFee);
    }

    modifier onlyOwner() {
        require(
            hasRole(OWNER_MARKETPLACE_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }
    modifier onlyTradeLotCreator(uint256 lotId) {
        require(
            tradingContract.getOwner(lotId) == msg.sender,
            "Caller is not an owner"
        );
        _;
    }
    modifier onlyAuctionLotCreator(uint256 auctionId) {
        require(
            auctionContract.getOwner(auctionId) == msg.sender,
            "Caller is not an owner or auction is not exist"
        );
        _;
    }
    modifier onlyAdmin() {
        require(
            hasRole(ADMIN_MARKETPLACE_ROLE, msg.sender),
            "Caller is not admin"
        );
        _;
    }

    function init(
        string memory _name,
        string memory _version,
        uint128 _platformFee
    ) external initializer returns (bool) {
        feeCollecter = payable(msg.sender);
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

    function setDependencies(
        address _tradingContract,
        address _auctionContract,
        address _nftToken
    ) external onlyOwner {
        tradingContract = ITrading(_tradingContract);
        auctionContract = IAuction(_auctionContract);
        nftToken = IERC1155Implementation(_nftToken);
    }

    function setallowedEditingPeriodOnStart(uint128 newValue)
        external
        onlyOwner
    {
        allowedEditingPeriodOnStart = newValue;
    }

    function setTimeExtendingRange(uint128 newTimeExtendingRange)
        external
        onlyOwner
    {
        timeExtendingRange = newTimeExtendingRange;
    }

    function setTimeExtendingValue(uint128 newTimeExtendingValue)
        external
        onlyOwner
    {
        timeExtendingValue = newTimeExtendingValue;
    }

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        feeCollecter = payable(newFeeCollector);
    }

    function collectFeeAndPay(
        uint256 value,
        uint256 tokenId,
        address creator
    ) private {
        uint256 fees = (value * uint256(platformFee)) / uint256(hundredPercent);
        feeCollecter.transfer(fees);
        (address receiver, uint256 royaltyAmount) = nftToken.royaltyInfo(
            tokenId,
            value
        );
        if (receiver != creator && royaltyAmount != 0) {
            fees += royaltyAmount;
            payable(receiver).transfer(royaltyAmount);
        }
        payable(creator).transfer(value - fees);
    }

    function transferAndUnlock(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) private {
        nftToken.unlockTokens(from, tokenId, amount);
        nftToken.safeTransferFrom(from, to, tokenId, amount, "");
    }

    function getAuctionInfo(uint256 auctionId)
        external
        view
        returns (IAuction.AuctionLot memory)
    {
        return auctionContract.getAuctionInfo(auctionId);
    }

    function getLotById(uint256 lotId)
        external
        view
        returns (ITrading.TradeLot memory lot)
    {
        lot = tradingContract.getLotById(lotId);
    }

    function getCurrentLotId() external view returns (uint256 nextId) {
        nextId = tradingContract.getCurrentLotId();
    }

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
        // require(startPrice > 0, "Start price must be bigger that zero");
        require(
            nftToken.isApprovedForAll(msg.sender, address(this)),
            "Token is not approved"
        );
        require(
            (nftToken.balanceOf(msg.sender, tokenId) -
                nftToken.getLockedTokensValue(msg.sender, tokenId)) >= amount,
            "Caller doesn`t have enough accessible token`s"
        );
        // require(
        //     nftToken.isCreator(msg.sender, tokenId),
        //     "Only NFT creator can start auction"
        // );
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
        uint256 auctionId = auctionContract.lastId();
        nftToken.lock(msg.sender, tokenId, amount);
        auctionContract.addAuctionLot(
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
            endTime,
            minDelta
        );
    }

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
        require(startPrice > 0, "Start price must be bigger that zero");
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
    }

    function delAuctionLot(uint256 auctionId)
        external
        onlyAuctionLotCreator(auctionId)
    {
        IAuction.AuctionLot memory auction = auctionContract.getAuctionInfo(
            auctionId
        );
        require(
            auction.lastBidder == address(0),
            "Impossible edit lot, if it is already have bids"
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
    }

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
        require(
            auction.minDelta == 0 && auction.lastBid == 0
                ? msg.value > auction.startPrice
                : msg.value >= auction.startPrice + auction.minDelta,
            "Bid is low"
        );
        require(
            auction.minDelta == 0
                ? msg.value > auction.lastBid
                : msg.value >= auction.lastBid + auction.minDelta,
            "Current bid is lower or equal last bid"
        );
        require(
            msg.sender != auction.auctionCreator,
            "Creator can`t place bid"
        );
        payable(auction.lastBidder).transfer(auction.lastBid);
        auctionContract.addBid(auctionId, msg.value, msg.sender);
        if (block.timestamp + timeExtendingRange > auction.endTime) {
            auctionContract.extendActionLifeTime(auctionId, timeExtendingValue);
            emit ExtendAuctionLifeTime(
                auctionId,
                auction.endTime + timeExtendingValue
            );
        }
        emit AddBid(auctionId, msg.sender, msg.value);
    }

    // rewrite flow. Better call this function by last bidder with admin sign
    function cancelAuction(
        uint256 auctionId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
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
        payable(auction.lastBidder).transfer(auction.lastBid);
        auctionContract.delAuctionLot(auctionId);
        emit DelAuctionLot(auctionId);
    }

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
        emit DelAuctionLot(auctionId);
    }

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

    function delTradeLot(uint256 lotId) external onlyTradeLotCreator(lotId) {
        ITrading.TradeLot memory lot = tradingContract.getLotById(lotId);
        nftToken.unlockTokens(msg.sender, lot.tokenId, lot.amount);
        tradingContract.delTradeLot(lotId);
        emit DelTradeLot(lotId);
    }

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