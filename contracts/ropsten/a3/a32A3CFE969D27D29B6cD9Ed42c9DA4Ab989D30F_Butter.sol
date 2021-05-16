// MIT License

// Code by zipzinger and cmtzco
// DEFIBOYS

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Butter is ERC721, Ownable {

    using Address for address payable;
    
    event NFTPurchased(address to, uint256 id);
    event NFTSwapApproved(uint256 id, address payable approvedAddress);
    event NFTListed(uint256 id, uint256 price);
    event NFTListingCancelled(uint256);
    event NFTSwapped(uint256 id, uint256 price);
    event butterRoyaltyPaid(address payable addressPaid, uint256 paymentAmount);

    uint256 public nftIndex;
    uint256 public maxNftCount;
    uint256 public currentPrice;
    address payable artistAddress;
    mapping (uint256 => bool) public tradeStatus;
    mapping (uint256 => uint256) public tradePrice;
    mapping (uint256 => address payable) public royaltyRecipients;
    mapping (uint256 => uint256) public royaltyPercents;
    uint256 public royaltyCount;

    constructor(uint256 _maxNftCount, uint256 _currentPrice, address payable _artistAddress, uint256 _royaltyPercent, string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {
        require(_currentPrice > 0, "NFT sale price must be higher than 0.");
        nftIndex = 0;
        royaltyCount = 0;
        maxNftCount = _maxNftCount;
        currentPrice = _currentPrice;
        artistAddress = _artistAddress;
        setNewRoyalty(1, _artistAddress, _royaltyPercent);
        uint256 butterPercent = SafeMath.sub(9500, _royaltyPercent);

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

        require(msg.value >= currentPrice, "Send more money. Buy failed");

        nftIndex += 1;
        assert(nftIndex <= maxNftCount);

        _butterMint(msg.sender, nftIndex);

        _setTradeStatus(nftIndex, false);
        _setTradePrice(nftIndex, 0);
        emit NFTPurchased(msg.sender, nftIndex);

        _payRoyalties(2, msg.value);
        _payRoyalties(1, msg.value);
    }

    function _payRoyalties(uint256 _royaltyIndex, uint256 _value) private {
        require(_royaltyIndex > 0);

        uint256 payPercent = royaltyPercents[_royaltyIndex];
        uint256 paymentAmount = SafeMath.div(SafeMath.mul(uint256(_value), uint256(payPercent)), uint256(10000));

        Address.sendValue(royaltyRecipients[_royaltyIndex], paymentAmount);

        if(_royaltyIndex == 1) {
            emit butterRoyaltyPaid(royaltyRecipients[_royaltyIndex], paymentAmount);
        }
    }

    function butterList(uint256 _id, uint256 _price) public {
        require(_isApprovedOrOwner(msg.sender, _id), "You aren't the owner of this NFT");
        _setTradeStatus(_id, true);
        _setTradePrice(_id, _price);

        emit NFTListed(_id, _price);
    }

    function butterSwap(uint256 _id) payable public {
        require(tradeStatus[_id] == true, "NFT not available for swap");
        require(tradePrice[_id] > 0, "NFT not available for swap");
        require(msg.value >= tradePrice[_id], "Insufficient money sent for swap");

        address originalOwner = ownerOf(_id);
        address newOwner = msg.sender;

        setApprovalForAll(newOwner, true);

        safeTransferFrom(originalOwner, newOwner, _id);

        // _payRoyalties(2, msg.value);
        // _payRoyalties(1, msg.value);

        _setTradeStatus(_id, false);
        _setTradePrice(_id, 0);

        setApprovalForAll(newOwner, false);

        emit NFTSwapped(_id, msg.value);
    }

    function butterListCancel(uint256 _id) public {
        require(_isApprovedOrOwner(msg.sender, _id), "You arent the owner of this NFT");

        _setTradeStatus(_id, false);
        _setTradePrice(_id, 0);

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