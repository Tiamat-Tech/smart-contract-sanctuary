// SPDX-License-Identifier: UNLICENSED

// Code by zipzinger and cmtzco
// DEFIBOYS
// defiboys.com

pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "./SwapMapping.sol";
// import { SwapMapping } from "./SwapMapping.sol";

import "./ButterManager.sol";


library SwapMapping {
    struct Map {
        uint256[] tradableNfts;
        mapping(uint256 => uint256) price;
        mapping(uint256 => uint256) indexOf;
        mapping(uint256 => bool) inserted;
    }

    function get(Map storage map, uint256 nftId) public view returns (uint256) {
        return map.price[nftId];
    }

    function getKeyAtIndex(Map storage map, uint256 index) public view returns (uint256) {
        return map.tradableNfts[index];
    }

    function size(Map storage map) public view returns (uint256) {
        return map.tradableNfts.length;
    }

    function set(Map storage map, uint256 key, uint256 val) public {
        if (map.inserted[key]) {
            map.price[key] = val;
        } else {
            map.inserted[key] = true;
            map.price[key] = val;
            map.indexOf[key] = map.tradableNfts.length;
            map.tradableNfts.push(key);
        }
    }

    function remove(Map storage map, uint256 key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.price[key];

        uint256 index = map.indexOf[key];
        uint256 lastIndex = map.tradableNfts.length - 1;
        uint256 lastKey = map.tradableNfts[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.tradableNfts[index] = lastKey;
        map.tradableNfts.pop();
    }
}

contract Butter is ERC721Enumerable, Ownable {

    using Address for address payable;
    using SwapMapping for SwapMapping.Map;
    
    event NFTPurchased(address to, uint256 id);
    event NFTSwapApproved(uint256 id, address payable approvedAddress);
    event NFTListed(uint256 id, uint256 price);
    event NFTListingCancelled(uint256);
    event NFTSwapped(uint256 id, uint256 price);
    event butterRoyaltyPaid(address payable addressPaid, uint256 paymentAmount);
    
    SwapMapping.Map private _swapMap;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    string public baseURI;
    uint256 public nftIndex;
    uint256 public maxNftCount;
    uint256 public currentPrice;
    address payable public artistAddress;
    address payable public butterManagerAddress;
    // mapping (uint256 => bool) public tradeStatus;
    // mapping (uint256 => uint256) public tradePrice;
    mapping (uint256 => address payable) public royaltyRecipients;
    mapping (uint256 => uint256) public royaltyPercents;
    uint256 public royaltyCount;

    constructor(uint256 _maxNftCount, address payable _butterManagerAddress, uint256 _currentPrice, address payable _artistAddress, uint256 _royaltyPercent, string memory nftName, string memory nftSymbol) ERC721(nftName, nftSymbol) {
        require(_currentPrice > 0, "NFT sale price must be higher than 0.");
        nftIndex = 0;
        royaltyCount = 0;
        maxNftCount = _maxNftCount;
        currentPrice = _currentPrice;
        artistAddress = _artistAddress;
        setNewRoyalty(1, _artistAddress, _royaltyPercent);
        uint256 butterPercent = SafeMath.sub(9500, _royaltyPercent);
        butterManagerAddress = _butterManagerAddress;

        address payable butterWallet = payable(msg.sender);
        setNewRoyalty(2, butterWallet, butterPercent);
    }

    function listedTokens() public view returns (uint256[] memory) {
        return _swapMap.tradableNfts;
    }

    function ownedTokens(address payable _addr) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(_addr);
        uint256[] memory result = new uint256[](balance);
        uint256 balId;

        for (balId = 0; balId < balance; balId++) {
            result[balId] = tokenOfOwnerByIndex(_addr,balId);
        }

        return result;
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

        _swapMap.remove(nftIndex);
        // _setTradeStatus(nftIndex, false);
        // _setTradePrice(nftIndex, 0);
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
        require(_price > 0, "The swap price must be greater than zero.");
        // _setTradeStatus(_id, true);
        // _setTradePrice(_id, _price);
        _swapMap.set(_id, _price);

        approve(butterManagerAddress, _id);
        emit NFTListed(_id, _price);
    }

    function butterSwap(uint256 _id) payable public {
        // require(tradeStatus[_id] == true, "Butter: NFT not available for swap");
        require(_swapMap.inserted[_id] == true, "Butter: NFT not available for swap");

        // require(tradePrice[_id] > 0, "Butter: NFT not available for swap");
        require(_swapMap.price[_id] > 0, "Butter: NFT not available for swap");

        // require(msg.value >= tradePrice[_id], "Butter: Insufficient money sent for swap");
        require(msg.value >= _swapMap.price[_id], "Butter: Insufficient money sent for swap");

        address payable originalOwner = payable(ownerOf(_id));

        _butterManagerSwap(msg.sender, _id);

        uint256 maxPayoutForRoyalties = SafeMath.div(SafeMath.mul(uint256(msg.value), uint256(2000)), uint256(10000));
        uint256 salePayoutForSeller = SafeMath.sub(msg.value, maxPayoutForRoyalties);

        Address.sendValue(originalOwner, salePayoutForSeller);

        _payRoyalties(2, maxPayoutForRoyalties);
        _payRoyalties(1, maxPayoutForRoyalties);

        // _setTradeStatus(_id, false);
        // _setTradePrice(_id, 0);
        _swapMap.remove(_id);

        emit NFTSwapped(_id, msg.value);
    }

    function butterListCancel(uint256 _id) public {
        require(_isApprovedOrOwner(msg.sender, _id), "You arent the owner of this NFT");

        _swapMap.remove(_id);
        // _setTradeStatus(_id, false);
        // _setTradePrice(_id, 0);

        emit NFTListingCancelled(_id);
    }

    function setManagerAddress(address payable _addr) public onlyOwner {
        butterManagerAddress = _addr;
    }

    function _butterManagerSwap(address _recipient, uint256 _id) private {
       ButterManager(butterManagerAddress).swap(_recipient, _id);
    }

    function butterManagerPerformSwap(address _recipient, uint256 _tokenID) public {
        require(msg.sender == butterManagerAddress);
        address originalOwner = ownerOf(_tokenID);
        safeTransferFrom(originalOwner, _recipient, _tokenID);
    }
    
    
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
    
    function setBaseURI(string memory _baseURIInput) public onlyOwner {
        baseURI = _baseURIInput;
    }

    function _butterMint(address _to, uint256 _id) private {
        _safeMint(_to, _id);
    }

    // function _setTradeStatus(uint256 _id, bool _status) private {
        // tradeStatus[_id] = _status;
    // }
    
    // function _setTradePrice(uint256 _id, uint256 _price) private {
        // tradePrice[_id] = _price;
    // }
}