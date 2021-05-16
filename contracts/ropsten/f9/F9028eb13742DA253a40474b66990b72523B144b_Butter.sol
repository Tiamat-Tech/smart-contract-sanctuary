pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Butter is ERC721, Ownable {

    using Address for address payable;
    
    event NFTPurchased(address to, uint256 id);
    event NFTListed(uint256 id, uint256 price);
    event NFTListingCancelled(uint256);
    event NFTSwapped(uint256 id, uint256 price);
    event butterRoyaltyPaid(address payable addressPaid, uint256 paymentAmount);

    // current nft index
    // [X] set on deploy
    // [X] +1 on successful buy
    uint256 public nftIndex;

    // maximum number of nfts
    // [X] set on deploy
    // [X] updatable function only by deployer
    uint256 public maxNftCount;


    // price in ethereum of NFT
    // [X] set on deploy
    // [X] updatable function only by deployer
    uint256 public currentPrice;

    // artist address
    // [X] set on deploy
    // [X] updatable by deployer
    address payable artistAddress;

    // mapping for trade statuses {id: tradeStatus}
    // [X] set trade status to false for new sales
    // [X] set value to true on listing
    // [X] after nft is traded, mark status back to false
    // [X] set value to false IF user wants to cancel trade, need cancel trade method
    mapping (uint256 => bool) public tradeStatus;
    
    // mapping for trade price {id: price}
    // [X] set trade price after nft-owner asks to trade
    // [X] zero out trade price after completed trade
    // [X] zero out trade price after cancelled trade
    mapping (uint256 => uint256) public tradePrice;


    // mapping for royalty recipient addresses
    // [X] need function to update recipients addresses
    mapping (uint256 => address payable) public royaltyRecipients;

    // mapping for royaltyPercents
    // [X] Need function to update percents by onlyOwner
    mapping (uint256 => uint256) public royaltyPercents;

    // variable where payments start and decrement
    // [X] increment this when adding new royaltyRecipient
    uint256 public royaltyCount;


    constructor(uint256 _maxNftCount, uint256 _currentPrice, address payable _artistAddress, uint256 _royaltyPercent, string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {
        require(_currentPrice > 0, "NFT sale price must be higher than 0.");
        nftIndex = 0;
        royaltyCount = 0;
        maxNftCount = _maxNftCount;
        currentPrice = _currentPrice;
        artistAddress = _artistAddress;
        setNewRoyalty(1, _artistAddress, _royaltyPercent);
        uint256 butterPercent = SafeMath.sub(10000, _royaltyPercent);

        address payable butterWallet = payable(msg.sender);
        setNewRoyalty(2, butterWallet, butterPercent);
    }

    function setRoyalty(uint256 _id, address payable _addr, uint256 _royaltyPercent) public onlyOwner {
        setRoyaltyAddress(_id, _addr);
        setRoyaltyPercent(_id, _royaltyPercent);
    }

    function setNewRoyalty(uint256 _id, address payable _addr, uint256 _royaltyPercent) public onlyOwner {
        setRoyaltyAddress(_id, _addr);
        setRoyaltyPercent(_id, _royaltyPercent);
        royaltyCount += 1;
    }

    function setRoyaltyAddress(uint256 _id, address payable _addr) public onlyOwner {
        royaltyRecipients[_id] = _addr;
    }

    function setRoyaltyPercent(uint256 _id, uint256 _royaltyPercent) public onlyOwner {
        royaltyPercents[_id] = _royaltyPercent;
    }

    function setArtistAddress(address payable _artistAddress) public onlyOwner {
        royaltyRecipients[1] = _artistAddress;
    }

    function setCurrentPrice(uint256 _currentPrice) public onlyOwner {
        require(_currentPrice > 0, "NFT sale price must be higher than 0.");
        currentPrice = _currentPrice;
    }

    function setMaxNFTCount(uint256 _count) public onlyOwner {
        require(_count > maxNftCount, "maxNFTCount must be larger than previous value");
        maxNftCount = _count;
    }



    function butterBuy() payable public {
        // did they send enough money?
        require(msg.value >= currentPrice, "Send more money. Buy failed");

        // are there any NFTs available?
        nftIndex += 1;
        assert(nftIndex <= maxNftCount);

        // transfer next available nft
        _butterMint(msg.sender, nftIndex);

        _setTradeStatus(nftIndex, false);
        _setTradePrice(nftIndex, 0);
        emit NFTPurchased(msg.sender, nftIndex);

        // handle royalties and payments
        // _payRoyalties(royaltyCount, msg.value);
    }

    function _payRoyalties(uint256 _royaltyIndex, uint256 _value) private {
        require(_royaltyIndex > 0);

        uint256 payPercent = royaltyPercents[_royaltyIndex];
        uint256 paymentAmount = SafeMath.div(SafeMath.mul(uint256(_value), uint256(payPercent)), uint256(10000));

        Address.sendValue(royaltyRecipients[_royaltyIndex], paymentAmount);

        uint256 nextPayment = _royaltyIndex--;
        
 
        if(_royaltyIndex == 1) {
            emit butterRoyaltyPaid(royaltyRecipients[_royaltyIndex], paymentAmount);
        }

        _payRoyalties(nextPayment, _value);
    }


    function butterList(uint256 _id, uint256 _price) public {
        // make sure caller owns that nft
        require(_isApprovedOrOwner(msg.sender, _id), "You aren't the owner of this NFT");
        
        // mark nft's tradeStatus true
        _setTradeStatus(_id, true);
        // set nfts tradePrice to price
        _setTradePrice(_id, _price);
        // create event for the listing
        emit NFTListed(_id, _price);
    }


    function butterSwap(uint256 _id) payable public {
        // verify nft is tradable
        require(tradeStatus[_id] == true, "NFT not available for swap");
        
        // prevent free swap
        require(tradePrice[_id] > 0, "NFT not available for swap");

        // verify they sent enough money
        require(msg.value >= tradePrice[_id], "Insufficient money sent for swap");

        address originalOwner = ownerOf(_id);
        address newOwner = msg.sender;

        safeTransferFrom(originalOwner, newOwner, _id);

        // _payRoyalties(royaltyCount, msg.value);

        _setTradeStatus(_id, false);
        _setTradePrice(_id, 0);
        
        emit NFTSwapped(_id, msg.value);
    }

    function butterListCancel(uint256 _id) public {
        // make sure caller owns that nft
        require(_isApprovedOrOwner(msg.sender, _id), "You arent the owner of this NFT");
        
        // mark nft's tradeStatus true
        _setTradeStatus(_id, false);
        // set nfts tradePrice to price
        _setTradePrice(_id, 0);
        // create event for the listing
        emit NFTListingCancelled(_id);
    }

    function _butterMint(address _to, uint256 _id) private {
        _safeMint(_to, _id);
    }

    function _setTradeStatus(uint256 _id, bool _status) private {
        tradeStatus[_id] = _status;
    }
    
    function _setTradePrice(uint256 _id, uint256 _price) private {
        tradePrice[_id] = _price;
    }
}