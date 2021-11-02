// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import {SubscriptionNFT} from './SubscriptionNFT.sol';
import {IProductHub} from './interfaces/IProductHub.sol';
import './Errors.sol';

import "hardhat/console.sol";

// TODO: rename to ProcutHub
contract ProductHub is IProductHub, Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    SubscriptionNFT public immutable nft;

    mapping(string => Product) /*productId*/
        internal _products;
    mapping(address => string[]) /*user*/ /*productIds*/
        internal _ownerProductIds;
    mapping(uint256 => uint256) /*tokenId*/ /*timestamp*/
        internal _tokenLastPeriodStartTimes;
    mapping(string => EnumerableSet.UintSet) /*productId*/ /*set of tokenIds*/
        internal _productTokens;

    // EnumerableSet.UintSet internal _cancelledSubscriptions;

    constructor() Ownable() {
        nft = new SubscriptionNFT(address(this));
    }

    function getOwnerProductIds(address owner) external view override returns (string[] memory) {
        return _ownerProductIds[owner];
    }

    function findTokenProduct(uint256 tokenId) public view override returns (string memory) {
        return nft.findTokenProduct(tokenId);
    }

    function getProductSubscribers(string memory productId) 
        public 
        view 
        override 
        returns (
            address[] memory, 
            uint[] memory, 
            uint[] memory, 
            uint[] memory
        ) 
    {
        EnumerableSet.UintSet storage tokens = _productTokens[productId];
        Product memory product = _products[productId];
        address[] memory addrs = new address[](tokens.length());
        uint[]    memory lastPeriodStartTime = new uint[](tokens.length());
        uint[]    memory periods = new uint[](tokens.length());
        uint[]    memory paymentAmounts = new uint[](tokens.length());

        for (uint i = 0; i < tokens.length(); i++) {
            uint token = tokens.at(i);
            addrs[i] = nft.ownerOf(token);
            lastPeriodStartTime[i] = _tokenLastPeriodStartTimes[token];
            periods[i] = (block.timestamp - lastPeriodStartTime[i]) / product.period;
            paymentAmounts[i] = product.price * periods[i];
        }

        return (addrs, lastPeriodStartTime, periods, paymentAmounts);
    }

    /// @notice Returns NFT token id a user owns, 0 means no token.
    function findTokenId(string memory productId, address user) public view override returns (uint256) {
        return nft.findTokenId(productId, user);
    }

    function getProductInfo(string memory productId)
        external
        view
        override
        returns (
            string memory id,
            string memory name,
            uint256 price,
            address payableToken,
            uint256 period,
            address productOwner,
            string memory metadataUri
        )
    {
        Product memory product = _products[productId];
        id = product.price == 0 ? '' : productId;
        name = product.name;
        price = product.price;
        payableToken = product.payableToken;
        period = product.period;
        productOwner = product.owner;
        metadataUri = product.metadataUri;
    }

    function createProduct(
        string memory productId,
        string memory name,
        address payableToken,
        uint256 price,
        uint256 period,
        string memory metadataUri
    ) external override {
        require(payableToken != address(0), Errors.ZERO_ADDRESS);
        require(price != 0, Errors.INVALID_PARAMS);
        require(period != 0, Errors.INVALID_PARAMS);
        require(_products[productId].price == 0, Errors.ALREADY_CREATED);

        _products[productId] = Product({
            name: name,
            price: price,
            payableToken: payableToken,
            period: period,
            owner: msg.sender,
            metadataUri: metadataUri
        });
        _ownerProductIds[msg.sender].push(productId);
        emit ProductCreated({
            owner: msg.sender,
            productId: productId,
            payableToken: payableToken,
            name: name,
            price: price,
            period: period,
            metadataUri: metadataUri
        });
    }

    function subscribe(string memory productId) external override {
        Product storage product = _products[productId];
        require(product.price != 0, 'PRODUCT_NOT_EXISTS');

        uint256 tokenId = nft.mint(msg.sender, productId, product.metadataUri);
        IERC20(product.payableToken).safeTransferFrom(msg.sender, product.owner, product.price);

        _productTokens[productId].add(tokenId);
        _tokenLastPeriodStartTimes[tokenId] = block.timestamp;

        emit SubscriptionCreated(msg.sender, productId, tokenId);
    }

    // function cancel(uint256 tokenId) external override {
    //     string memory productId = _tokenIdProductIds[tokenId];
    //     require(_products[productId].price == 0, 'PRODUCT_NOT_EXISTS');
    //     // TODO: implement
    // }

    function renewSubscription(uint256 tokenId) public override {
        string memory productId = nft.findTokenProduct(tokenId);
        require(_products[productId].price != 0, 'PRODUCT_NOT_EXISTS');

        Product memory product = _products[productId];
        address subscriber = nft.ownerOf(tokenId);

        // for simplicity this implementation either renews subscriptions
        // by charging for all periods or cancels without any charging
        // (even if a subscriber has allowance to cover a debt for some periods)
        uint256 lastPeriodStartTime = _tokenLastPeriodStartTimes[tokenId];
        uint256 periods = (block.timestamp - lastPeriodStartTime) / product.period;
        require(periods > 0, 'TOO_EARLY');
        uint256 paymentAmount = product.price * periods;

        IERC20 token = IERC20(product.payableToken);
        uint256 balance = token.balanceOf(subscriber);
        uint256 allowance = token.allowance(subscriber, address(this));
        if (balance >= paymentAmount && allowance >= paymentAmount) {
            _tokenLastPeriodStartTimes[tokenId] = lastPeriodStartTime + periods * product.period;
            token.safeTransferFrom(subscriber, product.owner, paymentAmount);
            emit SubscriptionRenewed(subscriber, productId, tokenId, msg.sender);
        } else {
            nft.burn(tokenId);
            delete _tokenLastPeriodStartTimes[tokenId];
            _productTokens[productId].remove(tokenId);
            emit SubscriptionCancelled(subscriber, productId, tokenId, msg.sender);
        }
    }

    function renewProductSubscription(string memory productId, address user) external override {
        require(_products[productId].price != 0, 'PRODUCT_NOT_EXISTS');
        uint256 tokenId = nft.findTokenId(productId, user);
        require(tokenId != 0, 'NOT_SUBSCRIBED');
        renewSubscription(tokenId);
    }

    function renewSubscriptions(uint256[] memory tokenIds) external override {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            renewSubscription(tokenIds[i]);
        }
    }

    function renewProductSubscriptions(string memory productId) external override {
        require(_products[productId].price != 0, 'PRODUCT_NOT_EXISTS');
        EnumerableSet.UintSet storage tokens = _productTokens[productId];
        for (uint256 i = 0; i < tokens.length(); i++) {
            renewSubscription(tokens.at(i));
        }
    }
}