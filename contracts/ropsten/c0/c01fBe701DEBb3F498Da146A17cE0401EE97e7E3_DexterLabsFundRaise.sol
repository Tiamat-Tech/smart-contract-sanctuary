// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DexterLabsFundRaise is ERC1155 {

    enum AuctionState { STOPPED, RUNNING, PAUSED, ENDED }

    address governance;
    uint256 currentTokenNumber;
    mapping(uint256 => uint256) nftTokenMapping;
    mapping(uint256 => uint256) listingPrice;
    mapping(uint256 => uint256) totalAmount;
    mapping(uint256 => uint256) balaceTokensForSale;
    mapping(uint256 => uint256) bidPrice;
    mapping(uint256 => AuctionState) auctionState;
    mapping(uint256 => address) bidWinner;

    constructor() ERC1155("https://cdn.dexterlabsfundraise.com/{id}") {
        governance = msg.sender;
        currentTokenNumber = 1;
    }

    // --------- INTERNAL FUNCTIONS ---------

    function createToken(address to) internal returns(uint256) {
        return createTokenBatch(to, 1);
    }

    function createTokenBatch(address to, uint256 amount) internal returns(uint256) {
        uint256 tokenNumber = currentTokenNumber;
        _mint(to, tokenNumber, amount, "");
        currentTokenNumber++;
        return tokenNumber;
    }

    // --------- PUBLIC FUNCTION ---------

    function getCurrentTokenNumber() internal view returns(uint256) {
        return currentTokenNumber;
    }

    function fractionalise(uint256 amount, uint256 _listingPrice, uint256 ownershipAmount) public returns(uint256) {
        require(ownershipAmount < amount);
        uint256 tokenNumber = createToken(governance);
        totalAmount[tokenNumber] = amount;
        balaceTokensForSale[tokenNumber] = amount - ownershipAmount;
        listingPrice[tokenNumber] = _listingPrice * 10e15;
        nftTokenMapping[tokenNumber] = currentTokenNumber;
        createTokenBatch(msg.sender, ownershipAmount);
        auctionState[tokenNumber] = AuctionState.STOPPED;
        bidPrice[tokenNumber] = 0;
        return tokenNumber;
    }

    function ownershipOfToken(address holder, uint256 tokenNumber) public view returns(uint256) {
        return balanceOf(holder, nftTokenMapping[tokenNumber]);
    }

    function amnountRequired(uint256 tokenNumber, uint256 amount) public view returns(uint256) {
        uint256 _listingPrice = listingPrice[tokenNumber];
        return _listingPrice * amount;
    }

    function purchaseShare(uint256 tokenNumber, uint256 amount) public payable {
        uint256 tokenBalance = balaceTokensForSale[tokenNumber];
        require(tokenBalance > 0, "No tokens left for sale");
        uint256 _listingPrice = listingPrice[tokenNumber];
        require(_listingPrice * amount < msg.value, "Not enough eth sent");
        uint256 numberTokens = amount;
        if (tokenBalance < numberTokens) {
            numberTokens = tokenBalance;
        }
        uint256 unUsedValue = msg.value - numberTokens * _listingPrice;
        _mint(msg.sender, nftTokenMapping[tokenNumber], numberTokens, "");
        balaceTokensForSale[tokenNumber] = balaceTokensForSale[tokenNumber] - numberTokens;
        payable(msg.sender).transfer(unUsedValue);
    }

    function startAuction(uint256 tokenNumber) public {
        require(msg.sender == governance);
        require(auctionState[tokenNumber] == AuctionState.STOPPED);
        bidPrice[tokenNumber] = listingPrice[tokenNumber] * totalAmount[tokenNumber];
        bidWinner[tokenNumber] = address(this);
        auctionState[tokenNumber] = AuctionState.RUNNING;
    }

    function getLastBigAmount(uint256 tokenNumber) public view returns(uint256) {
        return bidPrice[tokenNumber];
    }

    function bid(uint256 tokenNumber) public payable {
        require(bidPrice[tokenNumber] < msg.value, "Not enough money sent");
        require(auctionState[tokenNumber] == AuctionState.RUNNING);
        if (bidWinner[tokenNumber] != address(this)) {
            payable(bidWinner[tokenNumber]).transfer(bidPrice[tokenNumber]);
        }
        bidPrice[tokenNumber] = msg.value;
        bidWinner[tokenNumber] = msg.sender;
    }

    function pauseAuction(uint256 tokenNumber) public {
        require(msg.sender == governance);
        require(auctionState[tokenNumber] == AuctionState.RUNNING);
        auctionState[tokenNumber] = AuctionState.PAUSED;
    }

    function unpauseAuction(uint256 tokenNumber) public {
        require(msg.sender == governance);
        require(auctionState[tokenNumber] == AuctionState.PAUSED);
        auctionState[tokenNumber] = AuctionState.RUNNING;
    }

    function endAuction(uint256 tokenNumber) public {
        require(msg.sender == governance);  
        require(auctionState[tokenNumber] == AuctionState.RUNNING);
        auctionState[tokenNumber] = AuctionState.ENDED;
        safeTransferFrom(governance, bidWinner[tokenNumber], tokenNumber, 1, "");
    }

    function withdraw(uint256 tokenNumber) public payable {
        require(auctionState[tokenNumber] == AuctionState.ENDED);
        uint256 balance = balanceOf(msg.sender, nftTokenMapping[tokenNumber]);
        uint256 unitPrice = (bidPrice[tokenNumber] * balance) / totalAmount[tokenNumber];
        payable(msg.sender).transfer(unitPrice);
    }
}