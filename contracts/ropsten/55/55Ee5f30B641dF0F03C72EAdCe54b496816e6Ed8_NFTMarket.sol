// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarket is ERC721Holder, ERC1155Holder, AccessControl {
    bytes32 private constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR_ROLE");
    using SafeMath for uint256;

    uint256 private immutable BASE_PERCENT = 10**4;
    bytes private DEFAULT_MESSAGE;

    event AuctionLaunched(address, uint256);
    event NewBidReceived(uint256, address, uint256);
    event AuctionEnded(uint256, address, AuctionStatus);
    event AuctionEnded(
        uint256,
        address,
        AuctionStatus,
        uint256,
        uint256,
        uint256
    );
    event AuctionCancelled(uint256, address);
    event Log(string);

    enum TokenType {ERC721, ERC1155}
    enum AuctionStatus {Open, Sold, Unsold}
    struct AuctionInfo {
        address seller;
        address contractAddr; // Contract address
        uint256 tokenID; // Token ID
        TokenType tokenType;
        uint256 startPrice;
        uint16 creatorProfit; // 100 = 0.01
        uint16 storeProfit; // 200 = 0.02
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        address highestBidder;
        uint256 highestBid;
        uint256 lastBidTime;
        uint256 totalBids;
        uint256 createTime;
        AuctionStatus status;
    }

    AuctionInfo[] private auctionInfo;
    mapping(address => mapping(uint256 => uint256)) auctions;
    mapping(address => bool) public fullSupportContract;
    address private storeAddress;
    uint16 private storeDefaultProfit;
    uint16 private extraAuctionMinutes;

    constructor(address _fullSupportContract) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CONFIGURATOR_ROLE, _msgSender());

        fullSupportContract[_fullSupportContract] = true;
        storeAddress = _msgSender();
        storeDefaultProfit = 200;
        extraAuctionMinutes = 15;
    }

    function launchAuction(
        TokenType _tokenType,
        address _contractAddr,
        uint256 _tokenID,
        uint256 _startPrice,
        uint16 _creatorProfit,
        uint16 _storeProfit,
        uint256 _auctionStart,
        uint256 _auctionEnd
    ) public returns (uint256) {
        // Check token owner and transfer to this contract
        transferToken(
            _tokenType,
            _contractAddr,
            _tokenID,
            msg.sender,
            address(this)
        );

        if (isFullSupportContract(_contractAddr)) {
            require(
                _creatorProfit == 0,
                "Contract address didn't support creator profit."
            );
        }

        if (_auctionStart != 0 || _auctionEnd != 0) {
            require(_auctionEnd > _auctionStart, "Auction time error.");
        }
        checkProfit(_creatorProfit);
        checkProfit(_storeProfit);

        auctionInfo.push(
            AuctionInfo(
                msg.sender,
                _contractAddr,
                _tokenID,
                _tokenType,
                _startPrice,
                _creatorProfit,
                _storeProfit,
                _auctionStart,
                _auctionEnd,
                address(0),
                0,
                0,
                0,
                getNow(),
                AuctionStatus.Open
            )
        );

        uint256 index = auctionInfo.length.sub(1);
        auctions[_contractAddr][_tokenID] = index;

        emit AuctionLaunched(msg.sender, index);
        return auctions[_contractAddr][_tokenID];
    }

    function getAuctionId(address _contractAddr, uint256 _tokenID)
        public
        view
        returns (uint256)
    {
        return auctions[_contractAddr][_tokenID];
    }

    function getAuctionContractInfo(uint256 _auctionID)
        public
        view
        returns (address contractAddr, uint256 tokenID)
    {
        AuctionInfo memory auction = auctionInfo[_auctionID];

        contractAddr = auction.contractAddr;
        tokenID = auction.tokenID;
    }

    function getAuctionInfo(uint256 _auctionID)
        public
        view
        returns (
            address seller,
            TokenType tokenType,
            uint256 startPrice,
            uint16 creatorProfit,
            uint16 storeProfit,
            uint256 auctionStartTime,
            uint256 auctionEndTime,
            address highestBidder,
            uint256 highestBid,
            uint256 lastBidTime,
            uint256 totalBids,
            AuctionStatus status
        )
    {
        AuctionInfo memory auction = auctionInfo[_auctionID];

        seller = auction.seller;
        tokenType = auction.tokenType;
        startPrice = auction.startPrice;
        creatorProfit = auction.creatorProfit;
        storeProfit = auction.storeProfit;
        auctionStartTime = auction.auctionStartTime;
        auctionEndTime = auction.auctionEndTime;
        highestBidder = auction.highestBidder;
        highestBid = auction.highestBid;
        lastBidTime = auction.lastBidTime;
        totalBids = auction.totalBids;
        status = auction.status;
    }

    function getAuctionLength() public view returns (uint256) {
        return auctionInfo.length;
    }

    function bid(uint256 _auctionID) public payable returns (bool) {
        AuctionInfo storage auction = auctionInfo[_auctionID];

        checkStatus(auction.status, AuctionStatus.Open);
        require(
            isDirectBuy(auction.auctionStartTime, auction.auctionEndTime) == false,
            "Please pay fixed price for this product."
        );

        require(getNow() >= auction.auctionStartTime, "Auction not start yet");
        require(
            !isOverExtraEndTime(auction.auctionEndTime, auction.lastBidTime),
            "Auction already finished."
        );

        require(
            msg.value > auction.startPrice,
            "Your bid didn't higher than start price."
        );
        require(
            msg.value > auction.highestBid,
            "Your bid didn't higher than highest price"
        );

        // Refund to previous winner
        if (auction.totalBids != 0) {
            // Usually use transfer
            require(
                payable(auction.highestBidder).send(auction.highestBid),
                "Refound failed"
            );
        }

        // Record new winner
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
        auction.lastBidTime = getNow();
        auction.totalBids += 1;

        emit NewBidReceived(
            _auctionID,
            auction.highestBidder,
            auction.highestBid
        );
        return true;
    }

    function finalizeAuction(uint256 _auctionID) public payable {
        AuctionInfo storage auction = auctionInfo[_auctionID];

        checkStatus(auction.status, AuctionStatus.Open);
        if (isDirectBuy(auction.auctionStartTime, auction.auctionEndTime)) {
            require(
                msg.value == auction.startPrice,
                "Please check your price."
            );
            auction.highestBid = msg.value;
            auction.highestBidder = msg.sender;
            auction.lastBidTime = getNow();
            auction.totalBids += 1;
        } else {
            require(msg.value == 0, "Don't pay for this action.");
            require(
                isOverExtraEndTime(auction.auctionEndTime, auction.lastBidTime),
                "Auction not end."
            );
        }

        if (auction.totalBids == 0) {
            auction.status = AuctionStatus.Unsold;
            emit AuctionEnded(
                _auctionID,
                auction.highestBidder,
                auction.status
            );
        } else {
            // Caculate profit
            uint256 creatorProfit =
                auction.highestBid * (auction.creatorProfit / BASE_PERCENT);
            uint256 storeProfit =
                auction.highestBid * (auction.storeProfit / BASE_PERCENT);
            uint256 amount = auction.highestBid - (creatorProfit + storeProfit);

            if (storeProfit != 0) {
                payable(storeAddress).transfer(storeProfit);
            }

            if (creatorProfit != 0) {
                payable(
                    callContractRetAddr(
                        auction.contractAddr,
                        "creatorOf(uint256)",
                        auction.tokenID
                    )
                )
                    .transfer(creatorProfit);
            }

            payable(auction.seller).transfer(amount);

            // Transfer token to winner
            transferToken(
                auction.tokenType,
                auction.contractAddr,
                auction.tokenID,
                address(this),
                auction.highestBidder
            );

            // Finalize Auction
            auction.status = AuctionStatus.Sold;
            emit AuctionEnded(
                _auctionID,
                auction.highestBidder,
                auction.status,
                amount,
                creatorProfit,
                storeProfit
            );
        }
    }

    function cancelAuction(uint256 _auctionID) private {
        AuctionInfo storage auction = auctionInfo[_auctionID];

        require(auction.seller == msg.sender, "You are not seller.");
        checkStatus(auction.status, AuctionStatus.Open);

        transferToken(
            auction.tokenType,
            auction.contractAddr,
            auction.tokenID,
            address(this),
            auction.seller
        );

        if (auction.totalBids != 0) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.status = AuctionStatus.Unsold;
        emit AuctionCancelled(_auctionID, msg.sender);
    }

    function transferToken(
        TokenType _tokenType,
        address _contractAddr,
        uint256 _tokenID,
        address _from,
        address _to
    ) private {
        if (_tokenType == TokenType.ERC721) {
            IERC721 token = IERC721(_contractAddr);
            if (_to == address(this)) {
                require(
                    token.isApprovedForAll(msg.sender, address(this)),
                    "Approved not found"
                );
            }

            token.safeTransferFrom(_from, _to, _tokenID);
        } else {
            IERC1155 token = IERC1155(_contractAddr);
            if (_to == address(this)) {
                require(
                    token.isApprovedForAll(msg.sender, address(this)),
                    "Approved not found"
                );
            }

            token.safeTransferFrom(_from, _to, _tokenID, 1, DEFAULT_MESSAGE);
        }
    }

    function callContractRetAddr(
        address _contractAddr,
        string memory _abi,
        uint256 _tokenID
    ) private returns (address) {
        (bool successful, bytes memory retAddr) =
            _contractAddr.call(abi.encodeWithSignature(_abi, _tokenID));
        if (successful) {
            return abi.decode(retAddr, (address));
        } else {
            return address(0);
        }
    }

    function isDirectBuy(uint256 _auctionStratTime, uint256 _auctionEndTime)
        private
        pure
        returns (bool)
    {
        return _auctionStratTime == _auctionEndTime && _auctionStratTime == 0;
    }

    function isOverExtraEndTime(uint256 _auctionEndTime, uint256 _lastBidTime)
        private
        view
        returns (bool)
    {
        uint256 nowTime = getNow();
        if (_lastBidTime != 0) {
            uint256 extraEndTime =
                _lastBidTime + (extraAuctionMinutes * 1 minutes);
            if (extraEndTime > _auctionEndTime) {
                return nowTime > extraEndTime;
            } else {
                return nowTime > _auctionEndTime;
            }
        } else {
            return nowTime > _auctionEndTime;
        }
    }

    function setAuctionData(
        address _storeAddress,
        uint16 _storeProfit,
        uint16 _extraAuctionMinutes
    ) public onlyRole(CONFIGURATOR_ROLE) {
        checkProfit(_storeProfit);

        storeAddress = _storeAddress;
        storeDefaultProfit = _storeProfit;
        extraAuctionMinutes = _extraAuctionMinutes;
    }

    function setupFullSupportContract(
        address _fullSupportContract,
        bool _isSupport
    ) public onlyRole(CONFIGURATOR_ROLE) {
        fullSupportContract[_fullSupportContract] = _isSupport;
    }

    function isFullSupportContract(address _address)
        public
        view
        returns (bool)
    {
        return fullSupportContract[_address];
    }

    function getStoreAddress() public view returns (address) {
        return storeAddress;
    }

    function getStoreDefaultProfit() public view returns (uint16) {
        return storeDefaultProfit;
    }

    function getExtraAuctionMinutes() public view returns (uint16) {
        return extraAuctionMinutes;
    }

    function checkProfit(uint16 profit) private pure {
        require(profit >= 0, "Profit range error.");
        require(profit < BASE_PERCENT, "Profit range error.");
    }

    function checkStatus(AuctionStatus _status, AuctionStatus _expect)
        private
        pure
    {
        require(_status == _expect, "Auction status error.");
    }

    function getNow() public view returns (uint256) {
        return block.timestamp;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Receiver, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function transferToContract(address _contractAddr, uint256 _tokenID)
        external
    {
        IERC721 token = IERC721(_contractAddr);
        require(
            token.isApprovedForAll(msg.sender, address(this)),
            "Approved not found"
        );
        token.safeTransferFrom(msg.sender, address(this), _tokenID);
    }

    function transferBack(address _contractAddr, uint256 _tokenID) external {
        IERC721 token = IERC721(_contractAddr);
        token.safeTransferFrom(address(this), msg.sender, _tokenID);
    }
}