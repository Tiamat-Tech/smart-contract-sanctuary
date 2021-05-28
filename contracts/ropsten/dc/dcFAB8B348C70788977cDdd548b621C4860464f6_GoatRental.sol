// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./dependence/GoatAuctionBase.sol";
import "./interface/IGoatStatus.sol";
import "./interface/IGoatRentalWrapper.sol";


contract GoatRental is GoatAuctionBase, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct RentalOrder{
        address owner;
        address renter;
        address originToken;
        address currency;
        uint256[] originIds;
        uint256[] wrappedIds;
        uint256[] amounts;
        uint256 rentalTerm;
        uint256 repossessFee;
        bool repossessed;
        uint256[] subletRentalOrderIds;
    }

    uint256 public nextRentalOrderId = 1;

    uint256 public constant repossessFeeRate = 50;
    uint256 public constant repossessFeeRateBase = 10000;

    mapping(uint256 => uint256) public limitedPriceOrderRentalTerm;
    mapping(uint256 => uint256) public englishOrderRentalTerm;
    mapping(uint256 => RentalOrder) public rentalOrder;

    mapping(uint256 => uint256) private originRentalOrder;
    mapping(uint256 => mapping(uint256 => bool)) private isOriginRentalOrderSet;

    /** ====================  Event  ==================== */

    event LogLimitedPriceRental(address indexed seller, uint256 indexed orderId, address indexed token, address currency, uint256[] ids, uint256[] amounts, uint256 prices, uint256 rentalTerm);
    event LogLimitedPriceRentalCancel(uint256 indexed orderId);
    event LogLimitedPriceRentalBid(address indexed buyer, uint256 indexed orderId);

    event LogEnglishRental(address indexed seller, uint256 indexed orderId, address indexed token, address currency, uint256[] ids,  uint256[] amounts, uint256 startingPrices, uint256 deadline, uint256 rentalTerm);
    event LogEnglishRentalCancel(uint256 indexed orderId);
    event LogEnglishRentalBid(address indexed buyer, uint256 indexed orderId, uint256 indexed price);
    event LogEnglishRentalFinish(uint256 indexed orderId);

    event LogRentOut(uint256 indexed rentalId);
    event LogRepossess(uint256 indexed rentalId, address indexed executor, uint256 repossessFee);
    
    /** ====================  modifier  ==================== */

    modifier invalidRentalTerm(
        address _token,
        uint256[] memory _ids, 
        uint256 _rentalTerm
    ) { 
        require(_rentalTerm > block.timestamp, "2014: rental term should be longer than the current time");
        
        address goatRentalWrapper = goatStatus.rentalWrapperAddress();
        if (_token == goatRentalWrapper) {
            for(uint256 i = 0; i < _ids.length; i++) {
                (,,,uint256 term) = IGoatRentalWrapper(goatRentalWrapper).getWrapInfo(_ids[i]);
                require(_rentalTerm < term, "2015: rental term of sublet should be shorter than the origin");
            }  
        }
        _;
    }


    /** ====================  constractor  ==================== */
    constructor (
        address _goatStatusAddress
    ) 
        public 
        GoatAuctionBase(_goatStatusAddress)
    {}

    function getRentalOrder(
        uint256 _orderId
    ) 
        external 
        view 
        returns (
            address owner,
            address renter,
            address originToken,
            address currency,
            uint256[] memory originIds,
            uint256[] memory wrappedIds,
            uint256[] memory amounts,
            uint256 rentalTerm,
            uint256 repossessFee,
            bool repossessed,
            uint256[] memory subletRentalOrderIds
        ) 
    {
        require(_orderId < nextRentalOrderId, "2002: id not exist");
        RentalOrder memory order = rentalOrder[_orderId];
        return (
            order.owner,
            order.renter,
            order.originToken,
            order.currency,
            order.originIds,
            order.wrappedIds,
            order.amounts,
            order.rentalTerm,
            order.repossessFee,
            order.repossessed,
            order.subletRentalOrderIds
        );
    }

    /** ==================== repossess rental function  ==================== */
    function repossess(
        uint256 _rentalOrderId
    ) 
        external
        nonReentrant
    {
        RentalOrder memory order = rentalOrder[_rentalOrderId];
        if (order.subletRentalOrderIds.length > 0) {
            for (uint256 i = 0; i < order.subletRentalOrderIds.length; i++) {
                uint256 subletRentalOrderId = order.subletRentalOrderIds[i];
                if (!rentalOrder[subletRentalOrderId].repossessed) {
                    _repossess(subletRentalOrderId);
                }
            }
        }

        _repossess(_rentalOrderId);
    }

    /** ==================== limited price rental function  ==================== */

    function limitedPriceRental(
        address _currency,
        address _token,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256 _price,
        uint256 _rentalTerm
    ) 
        external 
        nonReentrant
        invalidRentalTerm(_token, _tokenIds, _rentalTerm)
    {
        uint256 orderId = _limitedPriceAuction(_currency, _token, _tokenIds, _amounts, _price);
        limitedPriceOrderRentalTerm[orderId] = _rentalTerm;
        
        goatStatus.setTokenStatus(msg.sender, _token, _tokenIds, _amounts, 2, 1);
        emit LogLimitedPriceRental(msg.sender, orderId, _token, _currency, _tokenIds, _amounts, _price, _rentalTerm);
    }

    function limitedPriceRentalCancel(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        _limitedPriceAuctionCancel(_orderId);
        
        emit LogLimitedPriceRentalCancel(_orderId);
    }

    function limitedPriceRentalBid(
        uint256 _orderId,
        address _currency,
        uint256 _price
    ) 
        external 
        payable 
        nonReentrant 
    {
        LimitedPriceOrder memory order = _limitedPriceAuctionBid(_orderId, _currency, _price);

        uint256 actualPrice = _rentOut(order.seller, msg.sender, order.token, order.ids, order.amounts, limitedPriceOrderRentalTerm[_orderId], order.currency, order.price);
        
        if (_currency == ethAddress) {
            payable(order.seller).transfer(actualPrice);
        } else {
            IERC20(_currency).safeTransfer(order.seller, actualPrice);
        }
        
        goatStatus.setTokenStatus(order.seller, order.token, order.ids, order.amounts, 3, 0);
        emit LogLimitedPriceRentalBid(msg.sender, _orderId);
    }

    /** ==================== english rental function  ==================== */

    function englishRental(
        address _currency,
        address _token,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256 _startingPrices,
        uint256 _deadline,
        uint256 _rentalTerm
    ) 
        external 
        nonReentrant
        invalidRentalTerm(_token, _tokenIds, _rentalTerm) 
    {
        uint256 orderId = _englishAuction(_currency, _token, _tokenIds, _amounts, _startingPrices, _deadline);
        englishOrderRentalTerm[orderId] = _rentalTerm;

        goatStatus.setTokenStatus(msg.sender, _token, _tokenIds, _amounts, 2, 2);
        emit LogEnglishRental(msg.sender, orderId, _token, _currency, _tokenIds, _amounts, _startingPrices, _deadline, _rentalTerm);
    }

    function englishRentalCancel(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        _englishAuctionCancel(_orderId);

        emit LogEnglishRentalCancel(_orderId);
    }

    function englishRentalBid(
        uint256 _orderId,
        address _currency,
        uint256 _price
    ) 
        external 
        payable 
        nonReentrant 
    {
        _englishAutionBid(_orderId, _currency, _price);

        emit LogEnglishRentalBid(msg.sender, _orderId, _price);
    }

    function englishRentalFinish(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        EnglishOrder memory order = _englishAuctionFinish(_orderId);

        if (order.highestPriceBuyer != address(0)) {
            uint256 actualPrice = _rentOut(order.seller, order.highestPriceBuyer, order.token, order.ids, order.amounts, englishOrderRentalTerm[_orderId], order.currency, order.highestPrice);
            if (order.currency == ethAddress) {
                payable(order.seller).transfer(actualPrice);
            } else {
                IERC20(order.currency).safeTransfer(order.seller, actualPrice);
            }
            goatStatus.setTokenStatus(order.seller, order.token, order.ids, order.amounts, 3, 0);
        } else {
            IERC1155(order.token).safeBatchTransferFrom(address(this), order.seller, order.ids, order.amounts, "");
            goatStatus.setTokenStatus(order.seller, order.token, order.ids, _getInitialArray(order.ids.length, 0), 0, 0);
        }
        
        emit LogEnglishRentalFinish(_orderId);
    }

    /** ==================== internal rental function  ==================== */
    function _rentOut(
        address _owner,
        address _renter,
        address _token,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        uint256 _rentalTerm,
        address _currency,
        uint256 _price
    ) 
        internal
        returns (uint256 actualPrice)
    {

        IERC1155(_token).setApprovalForAll(goatStatus.rentalWrapperAddress(), true);
        uint256[] memory wrappedIds = IGoatRentalWrapper(goatStatus.rentalWrapperAddress()).wrap(_owner, _token, _ids, _amounts, _renter, _rentalTerm);

        uint256 repossessFee = _price.mul(repossessFeeRate).div(repossessFeeRateBase);
        actualPrice = _price.sub(repossessFee);

        uint256 orderId = nextRentalOrderId;
        nextRentalOrderId++;

        uint256[] memory subletRentalOrderIds;
        rentalOrder[orderId] = RentalOrder(
            _owner,
            _renter,
            _token,
            _currency,
            _ids,
            wrappedIds,
            _amounts,
            _rentalTerm,
            repossessFee,
            false,
            subletRentalOrderIds
        );

        for (uint256 i = 0; i < _ids.length; i++) {
            if (_token != goatStatus.rentalWrapperAddress()){
                originRentalOrder[wrappedIds[i]] = orderId;
            } else {
                uint256 originRentalOrderId = originRentalOrder[_ids[i]];
                originRentalOrder[wrappedIds[i]] = originRentalOrderId;
                if (!isOriginRentalOrderSet[originRentalOrderId][orderId]) {
                    isOriginRentalOrderSet[originRentalOrderId][orderId] = true;
                    rentalOrder[originRentalOrderId].subletRentalOrderIds.push(orderId);
                }
            }
        }

        emit LogRentOut(orderId);
    }

    function _repossess(
        uint256 _rentalOrderId
    ) 
        internal 
    {
        require(_rentalOrderId < nextRentalOrderId, "2016: the rental order not exist");
        RentalOrder memory order = rentalOrder[_rentalOrderId];
        require(order.rentalTerm < block.timestamp, "2013: the auction is not over yet");
        require(!order.repossessed, "2017: the rental order has been repossessed");
        
        rentalOrder[_rentalOrderId].repossessed = true;

        address goatRentalWrapper = goatStatus.rentalWrapperAddress();
        IGoatRentalWrapper(goatRentalWrapper).unwrap(order.wrappedIds, order.amounts, order.owner);

        if (order.currency == ethAddress) {
            payable(msg.sender).transfer(order.repossessFee);
        } else {
            IERC20(order.currency).safeTransfer(msg.sender, order.repossessFee);
        }

        emit LogRepossess(_rentalOrderId, msg.sender, order.repossessFee);
    }

}