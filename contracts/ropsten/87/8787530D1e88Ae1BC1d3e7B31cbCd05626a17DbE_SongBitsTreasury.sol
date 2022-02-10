// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.9;

import "./interfaces/IParams.sol";
import "./interfaces/ICollection.sol";

import "./utils/Ownable.sol";

contract SongBitsTreasury is Ownable {
    mapping(address => IParams.Fees) private _fees;
    address private _factory;

    modifier notZeroFactoryAddress() {
        require(_factory != address(0));
        _;
    }

    constructor() {
        _transferOwnership(msg.sender);
    }

    function setFee(address _collection, IParams.Fees memory fees_)
        public
        notZeroFactoryAddress
    {
        require(
            ICollection(_collection).artist() == msg.sender ||
                _factory == msg.sender
        );
        _fees[_collection] = fees_;
    }

    function buy(address _collection, uint256 _tokenId)
        public
        payable
        notZeroFactoryAddress
    {
        ICollection collection = ICollection(_collection);
        require(collection.ownerOf(_tokenId) != msg.sender, "you token owner");
        require(
            collection.getMetadata(_tokenId).cost <= msg.value,
            "insufficient funds"
        );
        require(
            collection.getMetadata(_tokenId).hasPart == false,
            "solg has a part"
        );

        collection.approve(msg.sender, _tokenId);
        collection.safeTransferFrom(
            collection.ownerOf(_tokenId),
            msg.sender,
            _tokenId,
            ""
        );
        _revenue(
            payable(collection.artist()),
            payable(msg.sender),
            msg.value,
            _collection
        );
    }

    function buyPart(
        address _collection,
        uint256 _tokenId,
        uint256 boughtFrom,
        uint256 boughtTo
    ) public payable notZeroFactoryAddress {
        ICollection collection = ICollection(_collection);

        require(collection.ownerOf(_tokenId) != msg.sender, "you token owner");
        uint256 newId = collection.totalSupply() + 1;
        uint256 partCost = (collection.getMetadata(_tokenId).duration /
            collection.getMetadata(_tokenId).cost) * (boughtTo - boughtFrom);

        require(partCost <= msg.value, "insufficient funds");

        collection.mint(msg.sender, newId, partCost);
        collection.createMetadata(
            newId,
            boughtTo - boughtFrom,
            _tokenId,
            0,
            boughtTo,
            partCost,
            true,
            false
        );

        collection.getMetadata(_tokenId).hasPart = true;
        _revenue(
            payable(collection.artist()),
            payable(msg.sender),
            msg.value,
            _collection
        );
    }

    function setFactoryAddress(address factort_) public onlyOwner {
        _factory = factort_;
    }

    function _revenue(
        address payable _artist,
        address payable _fan,
        uint256 _amount,
        address _collection
    ) internal {
        IParams.Fees memory fees = _fees[_collection];

        uint256 claculatedAuthorFee = (_amount * fees._artistFeePrecent) / 100;
        uint256 claculatedFanFee = (_amount * fees._fanFeePercent) / 100;

        (bool ar, ) = _artist.call{value: claculatedAuthorFee}("");
        require(ar);

        (bool fr, ) = _fan.call{value: claculatedFanFee}("");
        require(fr);
    }
}