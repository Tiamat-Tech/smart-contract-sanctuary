// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./dependence/GoatAuctionBase.sol";
import "./interface/IGoatNFT.sol";


contract GoatSale is GoatAuctionBase, ReentrancyGuard  {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /** ====================  Event  ==================== */

    event LogLimitedPriceSale(address indexed seller, uint256 indexed orderId, address indexed token, address currency, uint256[] ids, uint256[] amounts, uint256 prices);
    event LogLimitedPriceSaleBid(address indexed buyer, uint256 indexed orderId);
    event LogLimitedPriceSaleCancel(uint256 indexed orderId);

    event LogEnglishSale(address indexed seller, uint256 indexed orderId, address indexed token, address currency, uint256[] ids,  uint256[] amounts, uint256 startingPrices, uint256 deadline);
    event LogEnglishSaleBid(address indexed buyer, uint256 indexed orderId, uint256 indexed price);
    event LogEnglishSaleFinish(uint256 indexed orderId);
    event LogEnglishSaleCancel(uint256 indexed orderId);

    event LogPayRoyalties(address indexed token, uint256 indexed id, address creator, uint256 amount, uint256 price, uint256 royalty);

/** ====================  constractor  ==================== */
    constructor (
        address _goatStatusAddress
    ) 
        public 
        GoatAuctionBase(_goatStatusAddress) 
    {}


    /** ==================== limited price sale function  ==================== */

    function limitedPriceSale(
        address _currency,
        address _token,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256 _price
    ) 
        external 
        nonReentrant 
    {
        uint256 orderId = _limitedPriceAuction(_currency, _token, _tokenIds, _amounts, _price);
        
        goatStatus.setTokenStatus(msg.sender, _token, _tokenIds, _amounts, 1, 1);
        emit LogLimitedPriceSale(msg.sender, orderId, _token, _currency, _tokenIds, _amounts, _price);
    }

    function limitedPriceSaleCancel(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        _limitedPriceAuctionCancel(_orderId);
        
        emit LogLimitedPriceSaleCancel(_orderId);
    }

    function limitedPriceSaleBid(
        uint256 _orderId,
        address _currency,
        uint256 _price
    ) 
        external 
        payable 
        nonReentrant 
    {
        LimitedPriceOrder memory order = _limitedPriceAuctionBid(_orderId, _currency, _price);

        _sendCurrencyToSeller(order.currency, order.seller, order.price, order.token, order.ids, order.amounts);

        IERC1155(order.token).safeBatchTransferFrom(address(this), msg.sender, order.ids, order.amounts, ""); 

        goatStatus.setTokenStatus(order.seller, order.token, order.ids, _getInitialArray(order.ids.length, 0), 0, 0);
        emit LogLimitedPriceSaleBid(msg.sender, _orderId);
    }

    /** ==================== english sale function  ==================== */

    function englishSale(
        address _currency,
        address _token,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        uint256 _startingPrices,
        uint256 _deadline
    ) 
        external 
        nonReentrant 
    {
        uint256 orderId = _englishAuction(_currency, _token, _tokenIds, _amounts, _startingPrices, _deadline);
        
        goatStatus.setTokenStatus(msg.sender, _token, _tokenIds, _amounts, 1, 2);
        emit LogEnglishSale(msg.sender, orderId, _token, _currency, _tokenIds, _amounts, _startingPrices, _deadline);
    }

    function englishSaleCancel(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        _englishAuctionCancel(_orderId);

        emit LogEnglishSaleCancel(_orderId);
    }

    function englishSaleBid(
        uint256 _orderId,
        address _currency,
        uint256 _price
    ) 
        external 
        payable 
        nonReentrant 
    {
        _englishAutionBid(_orderId, _currency, _price);

        emit LogEnglishSaleBid(msg.sender, _orderId, _price);
    }

    function englishSaleFinish(
        uint256 _orderId
    ) 
        external 
        nonReentrant 
    {
        EnglishOrder memory order = _englishAuctionFinish(_orderId);

        if (order.highestPriceBuyer != address(0)) {

            _sendCurrencyToSeller(order.currency, order.seller, order.highestPrice, order.token, order.ids, order.amounts);

            IERC1155(order.token).safeBatchTransferFrom(address(this), order.highestPriceBuyer, order.ids, order.amounts, "");
        } else {

            IERC1155(order.token).safeBatchTransferFrom(address(this), order.seller, order.ids, order.amounts, "");
        }

        goatStatus.setTokenStatus(order.seller, order.token, order.ids, _getInitialArray(order.ids.length, 0), 0, 0);
        emit LogEnglishSaleFinish(_orderId);
    }

    function _sendCurrencyToSeller(
        address _currency,
        address _receiver,
        uint256 _price,
        address _token,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) internal {

        if (_token == goatStatus.goatNFTAddress()) {
            uint256 totalAmount;
            uint256 totalRoyalty;

            for (uint256 i = 0; i < _amounts.length; i++) {
                totalAmount = totalAmount.add(_amounts[i]);
            }

            for (uint256 i = 0; i < _ids.length; i++) {
                uint256 id = _ids[i];
                address creator = IGoatNFT(_token).creators(id);
                uint256 thisIdPrice = _price.mul(_amounts[i]).div(totalAmount);
                uint256 royalty = thisIdPrice.mul(IGoatNFT(_token).royalty(id)).div(IGoatNFT(_token).royaltyBase());
                _transferOut(_currency, creator, royalty);

                emit LogPayRoyalties(_token, id, creator, _amounts[i], thisIdPrice, royalty);

                totalRoyalty = totalRoyalty.add(royalty);
            }

            _price = _price.sub(totalRoyalty);
        }

        _transferOut(_currency, _receiver, _price);
    }

    function _transferOut(
        address _currency,
        address _receiver,
        uint256 _price
    ) internal {
        if (_currency == ethAddress) {
            payable(_receiver).transfer(_price);
        } else {
            IERC20(_currency).safeTransfer(_receiver, _price);
        }
    }
}