// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ICryptoOwlCollection.sol";

contract CryptoOwlCollection is Ownable, ICryptoOwlCollection {
    using Counters for Counters.Counter;
    using Address for address;

    Counters.Counter private _nextCollectionId;

    address cryptoOwlContractAddress;

    mapping(uint256 => uint256) public tokenToCollection;
    mapping(uint256 => Collection) public collections;
    mapping(uint256 => mapping(uint256 => uint256))
        public collectionSerialNumberToToken;
    mapping(uint256 => address) public collectionCreators;

    constructor() {
        _nextCollectionId.increment();
    }

    modifier onlyExistingCollection(uint256 collectionId) {
        require(
            collectionCreators[collectionId] != address(0),
            "CryptoOwlCollection: collection does not exist"
        );
        _;
    }

    modifier onlyCryptoOwl() {
        require(
            _msgSender() == cryptoOwlContractAddress,
            "CryptoOwlCollection: invalid caller"
        );
        _;
    }

    function setCryptoOwlContract(address _cryptoOwlContractAddress)
        external
        override
        onlyOwner
    {
        require(
            _cryptoOwlContractAddress.isContract(),
            "CryptoOwlCollection: should be a contract"
        );
        cryptoOwlContractAddress = _cryptoOwlContractAddress;
    }

    function addCollection(Collection calldata _collection)
        external
        override
        returns (uint256)
    {
        require(
            _collection.name != 0,
            "CryptoOwlCollection: collection name is required"
        );
        require(
            _collection.amount == 0,
            "CryptoOwlCollection: collection initial amount should be 0"
        );
        uint256 collectionId = _nextCollectionId.current();
        _nextCollectionId.increment();
        collections[collectionId] = _collection;
        collectionCreators[collectionId] = _msgSender();
        emit CollectionAdded(collectionId, _msgSender());
        return collectionId;
    }

    function addTokenToCollection(
        uint256 tokenId,
        uint256 collectionId,
        uint256 serialNumber
    ) external override onlyCryptoOwl {
        if (!collections[collectionId].isPublic) {
            require(
                tx.origin == collectionCreators[collectionId],
                "CryptoOwlCollection: not the collection creator"
            );
        }

        require(
            tokenToCollection[tokenId] == 0,
            "CryptoOwlCollection: already added to a collection"
        );

        if (collections[collectionId].limit > 0) {
            require(
                collections[collectionId].amount <
                    collections[collectionId].limit,
                "CryptoOwlCollection: the collection amount exceeds the limit"
            );
        }

        if (serialNumber > 0) {
            require(
                collectionSerialNumberToToken[collectionId][serialNumber] == 0,
                "CryptoOwlCollection: the serial number is already in use"
            );
        }
        tokenToCollection[tokenId] = collectionId;
        collectionSerialNumberToToken[collectionId][serialNumber] = tokenId;
        collections[collectionId].amount += 1;
    }

    function getCollection(uint256 collectionId)
        external
        view
        override
        onlyExistingCollection(collectionId)
        returns (Collection memory)
    {
        return collections[collectionId];
    }
}