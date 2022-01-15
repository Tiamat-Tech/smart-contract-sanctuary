// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BarterPlace is Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _offerIdCounter;
    
    uint256 private _createOfferFee;
    uint256 private _acceptOfferFee;
    
    enum OfferStatus {
        Pending,
        Canceled,
        Fulfilled,
        Rejected
    }
    
    enum BarterAssetType {
        ERC721,
        ERC20,
        ERC1155
    }

    struct BarterAsset {
        address contractAddress;
        uint256 tokenId;
        BarterAssetType assetType;
        uint256 amount;
    }
    
    struct BarterOffer {
        uint256 id;
        address side0;
        address side1;
        BarterAsset[] side0Assets;
        BarterAsset[] side1Assets;
        OfferStatus status;
        uint256 createdAt;
        uint256 updatedAt;
        uint256 deadline;
    }
    
    mapping (uint256 => BarterOffer) offersById;
    mapping (address => uint256[]) offersByAddress;
    
    event OfferCreated(uint offerId, address side0, address side1);
    event OfferAccepted(uint offerId, address side0, address side1);
    event OfferCanceled(uint offerId, address side0, address side1);
    
    constructor () Ownable () {
        
    } 
    
    function setCreateOfferFee (uint256 newOfferFee) public onlyOwner {
        _createOfferFee = newOfferFee;
    }
    
    function createOfferFee () public view returns (uint256) {
        return _createOfferFee;
    }
    
    function setAcceptOfferFee (uint256 newOfferFee) public onlyOwner {
        _acceptOfferFee = newOfferFee;
    }

    function acceptOfferFee () public view returns (uint256) {
        return _acceptOfferFee;
    }

    function withdrawBalance (address payable to) public onlyOwner {
        to.transfer(address(this).balance);
    }
    
    // Barter between side0 and side1 addresses
    // side0 - msg.sender
    // side1 - specified in call
    function createOffer (
        address side1,
        BarterAsset[] calldata side0Assets,
        BarterAsset[] calldata side1Assets,
        uint256 deadline) payable public {
        address side0 = msg.sender;

        require(msg.value >= _createOfferFee, "Invalid create offer fee amount");
    
        uint256 offerId = _offerIdCounter.current();
        
        offersById[offerId].status = OfferStatus.Pending;
        offersById[offerId].id = offerId;
        offersById[offerId].side0 = side0;
        offersById[offerId].side1 = side1;
        offersById[offerId].createdAt = block.timestamp;
        offersById[offerId].deadline = deadline;
        
        for (uint256 i = 0; i < side0Assets.length; ++i) {
            offersById[offerId].side0Assets.push(side0Assets[i]);
        }
        for (uint256 i = 0; i < side1Assets.length; ++i) {
            offersById[offerId].side1Assets.push(side1Assets[i]);
        }
        
        offersByAddress[side0].push(offerId);
        offersByAddress[side1].push(offerId);
        
        _offerIdCounter.increment();
        
        emit OfferCreated(offerId, side0, side1);
    }
    
    function acceptOffer (uint256 offerId) payable public {
        BarterOffer storage offer = offersById[offerId];
        require(offer.side1 == address(0) || offer.side1 == msg.sender, 'Sender is not offer participant');
        require(offer.status == OfferStatus.Pending, 'Offer status is not pending (canceled or fulfilled)');
        require(offer.deadline == 0 || block.timestamp <= offer.deadline, 'Offer expired');
        require(msg.value >= _acceptOfferFee, "Invalid accept offer fee amount");

        offer.status = OfferStatus.Fulfilled;
        offer.updatedAt = block.timestamp;
        
        _transferAssets(offer.side0, msg.sender, offer.side0Assets);
        _transferAssets(msg.sender, offer.side0, offer.side1Assets);
        
        emit OfferAccepted(offer.id, offer.side0, msg.sender);
    }
    
    function cancelOffer (uint256 offerId) public {
        BarterOffer storage offer = offersById[offerId];
        require(offer.side0 == msg.sender, 'Sender is not offer initiator');
        require(offer.status == OfferStatus.Pending, 'Offer status is not pending (canceled or fulfilled)');

        offer.status = OfferStatus.Canceled;
        offer.updatedAt = block.timestamp;
        emit OfferCanceled(offer.id, offer.side0, offer.side1);
    }

    function _transferAssets(address from, address to, BarterAsset[] storage assets) internal {
        for (uint256 i = 0; i < assets.length; ++i) {
            if (assets[i].assetType == BarterAssetType.ERC721) {
                IERC721 erc721Contract = IERC721(assets[i].contractAddress);
                erc721Contract.safeTransferFrom(from, to, assets[i].tokenId);
            } else if (assets[i].assetType == BarterAssetType.ERC20) {
                IERC20 erc20Contract = IERC20(assets[i].contractAddress);
                erc20Contract.transferFrom(from, to, assets[i].amount);
            } else if (assets[i].assetType == BarterAssetType.ERC1155) {
                IERC1155 erc1155Contract = IERC1155(assets[i].contractAddress);
                erc1155Contract.safeTransferFrom(from, to, assets[i].tokenId, assets[i].amount, "");
            }
        }
    }
    
    function getOffersIdsByAddress (address targetAddress) public view returns (uint256[] memory) {
        return offersByAddress[targetAddress];
    }
    
    function getOffersByIds (uint256[] memory offersIds) public view returns (BarterOffer[] memory) {
        BarterOffer[] memory offers = new BarterOffer[](offersIds.length);
        for (uint256 i = 0; i < offersIds.length; ++i) {
            offers[i] = offersById[offersIds[i]];
        }
        return offers;
    }
    
    function getOffersByAddress (address targetAddress) public view returns (BarterOffer[] memory) {
        return getOffersByIds(getOffersIdsByAddress(targetAddress));
    }
    
    function getRecentOfferId () public view returns (uint256) {
        return _offerIdCounter.current() - 1;
    }
}