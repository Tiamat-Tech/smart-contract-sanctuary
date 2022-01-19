// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './NFTMarketplaceStorage.sol';
import './erc2981/IERC2981Royalties.sol';

contract NFTMarketplace is
    Ownable,
    Pausable,
    NFTMarketplaceStorage,
    IERC721Receiver
{
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    // whitelist
    EnumerableSet.AddressSet private _contractWhitelist;

    // constants
    address constant ADDRESS_NULL = address(0);
    uint256 constant platformFee = 5;
    uint256 constant feePercentage = 100;

    // state
    mapping(address => EnumerableSet.UintSet)
        private _contractsToSenderTokenIdList;
    mapping(uint256 => Offer) private _contractsTokenIdToOffer;

    constructor(address payable _recipientAddress) {
        recipientAddress = _recipientAddress;
    }

    function addWhitelistContract(address _nftContract) public onlyOwner {
        _contractWhitelist.add(_nftContract);
    }

    function deleteWhitelistContract(address _nftContract) public onlyOwner {
        _contractWhitelist.remove(_nftContract);
    }

    function isWhitelistContract(address _nftContract)
        public
        view
        returns (bool)
    {
        return _contractWhitelist.contains(_nftContract);
    }

    function getNFTOfferIdList(address _nftContract)
        public
        view
        returns (uint256[] memory)
    {
        return _contractsToSenderTokenIdList[_nftContract].values();
    }

    function getOffer(address _nftContract, uint256 _tokenId)
        public
        view
        returns (
            uint256,
            address,
            uint256
        )
    {
        uint256 offerId = toUint256(_nftContract).add(_tokenId);
        return (
            _contractsTokenIdToOffer[offerId].tokenId,
            _contractsTokenIdToOffer[offerId].seller,
            _contractsTokenIdToOffer[offerId].price
        );
    }

    function makeOffer(
        address _nftContract,
        uint256 _tokenId,
        uint256 _price
    ) public whenNotPaused {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == msg.sender,
            'sender dont own tokenId'
        );
        uint256 sellerindex = toUint256(msg.sender).add(_tokenId);
        require(
            !_contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'offer is already created'
        );

        uint256 offerId = toUint256(_nftContract).add(_tokenId);
        Offer storage offer = _contractsTokenIdToOffer[offerId];
        offer.offerId = offerId;
        offer.tokenId = _tokenId;
        offer.seller = msg.sender;
        offer.price = _price;

        _contractsToSenderTokenIdList[_nftContract].add(sellerindex);

        emit OfferMaked(_nftContract, _tokenId, msg.sender, _price);
    }

    function buyOffer(address _nftContract, uint256 _tokenId) public payable {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );
        uint256 offerId = toUint256(_nftContract).add(_tokenId);
        Offer storage _offer = _contractsTokenIdToOffer[offerId];

        require(
            _offer.seller != ADDRESS_NULL && _offer.seller != msg.sender,
            'wrong seller address'
        );
        uint256 sellerindex = toUint256(_offer.seller).add(_tokenId);
        require(
            _contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'offer is not created'
        );

        require(_offer.tokenId == _tokenId, 'different nft products');
        require(
            IERC721(_nftContract).ownerOf(_tokenId) == _offer.seller,
            'offer seller is different owner of token'
        );
        require(
            msg.value == _offer.price,
            'The ETH amount should match with the NFT Price'
        );

        IERC721(_nftContract).safeTransferFrom(
            _offer.seller,
            msg.sender,
            _tokenId
        );

        uint256 recipientAmount = _offer.price.mul(platformFee).div(
            feePercentage
        );

        address brandAddress;
        uint256 brandFee;
        address collabAddress;
        uint256 collabFee;
        (brandAddress, brandFee, collabAddress, collabFee) = IERC2981Royalties(
            _nftContract
        )
            .royaltyInfo(_tokenId);

        if (brandAddress != ADDRESS_NULL) {
            brandFee = _offer.price.mul(brandFee).div(feePercentage);
        }
        if (collabAddress != ADDRESS_NULL) {
            collabFee = _offer.price.mul(collabFee).div(feePercentage);
        }

        uint256 sellAmount = _offer
            .price
            .sub(recipientAmount)
            .sub(brandFee)
            .sub(collabFee);

        recipientAddress.transfer(recipientAmount);
        if (brandAddress != ADDRESS_NULL)
            payable(brandAddress).transfer(brandFee);
        if (collabAddress != ADDRESS_NULL)
            payable(collabAddress).transfer(collabFee);
        payable(_offer.seller).transfer(sellAmount);

        delete _contractsTokenIdToOffer[offerId];
        _contractsToSenderTokenIdList[_nftContract].remove(sellerindex);

        emit OfferBought(_nftContract, _tokenId, msg.value, msg.sender);
    }

    function cancelOffer(address _nftContract, uint256 _tokenId) public {
        require(_nftContract.isContract(), 'should be a contract');
        require(
            _contractWhitelist.contains(_nftContract),
            'contract must be white listed'
        );

        uint256 offerId = toUint256(_nftContract).add(_tokenId);
        Offer storage _offer = _contractsTokenIdToOffer[offerId];

        require(
            _offer.seller != ADDRESS_NULL && _offer.seller == msg.sender,
            'wrong seller address'
        );
        uint256 sellerindex = toUint256(_offer.seller).add(_tokenId);
        require(
            _contractsToSenderTokenIdList[_nftContract].contains(sellerindex),
            'offer is not created'
        );

        delete _contractsTokenIdToOffer[offerId];
        _contractsToSenderTokenIdList[_nftContract].remove(sellerindex);

        emit OfferCanceled(_nftContract, _tokenId, msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override returns (bytes4) {
        return
            bytes4(
                keccak256('onERC721Received(address,address,uint256,bytes)')
            );
    }

    // Fallback: reverts if Ether is sent to this smart-contract by mistake
    fallback() external {
        revert();
    }
}