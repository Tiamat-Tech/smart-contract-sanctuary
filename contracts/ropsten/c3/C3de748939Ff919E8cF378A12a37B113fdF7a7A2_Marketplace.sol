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
    address public feeCollecter;
    uint128 constant hundredPercent = 100000; //100 *1000
    uint128 public plaftormFee;
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
    event ChangePlatformFee(uint128 newPlatformFee);
    event DelTradeLot(uint256 lotId);

    function setPlatformFee(uint128 newPlatformFee) public onlyOwner {
        require(
            newPlatformFee <= hundredPercent,
            "Limit of platform fee amount"
        );
        plaftormFee = newPlatformFee;
        emit ChangePlatformFee(newPlatformFee);
    }

    modifier onlyOwner() {
        require(
            hasRole(OWNER_MARKETPLACE_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }
    modifier onlyLotCreator(uint256 lotId) {
        require(
            tradingContract.getOwner(lotId) == msg.sender,
            "Caller is not an owner"
        );
        _;
    }

    function init(
        string memory _name,
        string memory _version,
        uint128 _plaftormFee
    ) external initializer returns (bool) {
        feeCollecter = msg.sender;
        __Signature_init(_name, _version);
        _setupRole(OWNER_MARKETPLACE_ROLE, msg.sender);
        _setRoleAdmin(OWNER_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        _setRoleAdmin(SIGNER_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        setPlatformFee(_plaftormFee);
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

    function addAuctionLot() external {}

    function delAuctionLot() external {}

    function addBid() external {}

    function getNFTWithAuctionLot() external {}

    function unlockNFTWithAuctionLot() external {}

    function setFeeCollector(address newFeeCollector) external onlyOwner {
        feeCollecter = newFeeCollector;
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
        require(nftToken.isApprovedForAll(msg.sender, address(this)), "");
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
    ) external onlyLotCreator(lotId) {
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

    function delTradeLot(uint256 lotId) external onlyLotCreator(lotId) {
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
        (address receiver, uint256 royaltyAmount) = nftToken.royaltyInfo(
            lot.tokenId,
            lot.amount * lot.price
        );

        uint256 fees = (msg.value * uint256(plaftormFee)) /
            uint256(hundredPercent);
        nftToken.unlockTokens(lot.lotCreator, lot.tokenId, amount);
        nftToken.safeTransferFrom(
            lot.lotCreator,
            msg.sender,
            lot.tokenId,
            amount,
            ""
        );
        payable(feeCollecter).transfer(fees);
        if (receiver != lot.lotCreator && royaltyAmount != 0) {
            fees += royaltyAmount;
            payable(receiver).transfer(royaltyAmount);
        }
        payable(lot.lotCreator).transfer(msg.value - fees);
        tradingContract.changeAmount(lotId, lot.amount - amount);
        emit BuyNFTFromLot(lotId, lot.lotCreator, msg.sender, amount);
        if (lot.amount - amount == 0) {
            tradingContract.delTradeLot(lotId);
            emit DelTradeLot(lotId);
        }
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
}