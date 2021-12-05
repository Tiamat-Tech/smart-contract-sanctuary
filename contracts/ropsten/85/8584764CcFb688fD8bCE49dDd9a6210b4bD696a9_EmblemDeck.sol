// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./EmblemDeckWithAuctions.sol";
import "./EmblemDeckWithTraits.sol";

contract EmblemDeck is
    EmblemDeckWithAuctions,
    EmblemDeckWithTraits,
    ReentrancyGuard
{
    constructor() ERC721("Dark Emblem", "DECK") {
        _pause();
        ceoAddress = payable(msg.sender);
        cooAddress = payable(msg.sender);
        cfoAddress = payable(msg.sender);

        // Create card 0 and give it to the contract so no one can have it
        _createCard(0, 0, 0, currentPackId, 0x00, uint256(0), address(this));
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function createPromoCard(
        uint32 packId,
        uint32 cardType,
        uint256 traits,
        address owner
    ) external onlyCOO {
        address cardOwner = owner;
        if (cardOwner == address(0)) {
            cardOwner = cooAddress;
        }

        _createCard(0, 0, 0, packId, cardType, traits, cardOwner);
    }

    function _buyCards(
        uint256 numCards,
        address _cardOwner,
        uint256 boost
    ) internal nonReentrant {
        uint256 salt = randNonce + 255;
        uint256 numHeroCards = _getRandomInRange(1, numCards, salt++);
        uint256 numOtherCards = numCards - numHeroCards;

        for (uint256 i = 0; i < numHeroCards; i++) {
            //slither-disable-next-line calls-loop -- we have an upper bound and own the contract
            _createCard(
                0,
                0,
                0,
                currentPackId,
                0x00,
                ascendScience.getRandomTraits(i, salt++, boost),
                _cardOwner
            );
        }

        for (uint256 i = 0; i < numOtherCards; i++) {
            //slither-disable-next-line calls-loop -- we have an upper bound and own the contract
            _createCard(
                0,
                0,
                0,
                currentPackId,
                uint32(_getRandomInRange(1, maxCardTypes, salt++)),
                ascendScience.getRandomTraits(i + numHeroCards, salt++, boost),
                _cardOwner
            );
        }

        randNonce += salt;
        seasonPacksMinted = seasonPacksMinted + 1;
    }

    function _buyPackBulk(address cardOwner, uint256 numPacks) internal {
        uint256 maxBulkPacks = 5;
        // Make sure nothing crazy happens with numPacks
        require(numPacks <= maxBulkPacks, "Too many packs requested");
        require(numPacks > 0, "Zero packs requested");
        require(
            seasonPacksMinted < seasonPackLimit,
            "Cannot mint any more packs this season"
        );

        uint32 boost = 0;

        if (numPacks >= maxBulkPacks) {
            boost = 100;
        } else if (numPacks >= 2) {
            boost = 40;
        } else {
            boost = 0;
        }

        _buyCards(currentCardsPerPack * numPacks, cardOwner, boost);
    }

    function buyPack() external payable whenNotPaused {
        require(msg.value >= currentPackPrice);

        address cardOwner = msg.sender;
        (bool div, uint256 numPacks) = SafeMath.tryDiv(
            msg.value,
            currentPackPrice
        );

        require(div, "Divide by 0 error");

        _buyPackBulk(cardOwner, numPacks);
    }

    /// @dev buy packs using $DREM
    /// - You can buy a pack for someone else.
    /// - You can bulk-buy packs with amount
    function buyPackWithDrem(address to, uint256 amount)
        external
        whenNotPaused
    {
        require(to != address(0), "Cannot buy a pack for 0x0");
        require(
            address(emblemTokenERC20) != address(0),
            "ERC20 Contract not set"
        );

        // Transfer sale amount to seller
        bool sent = emblemTokenERC20.transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(sent, "Token transfer failed");

        _buyPackBulk(to, amount);
    }
}