pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ICollectionRegistry.sol";

contract CollectionRegistry is ICollectionRegistry {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    struct Record {
        address owner;
        address addr;
        string name;
    }

    // mapping from collectionId into collection address
    mapping(bytes32 => Record) public records;
    // allows to iterate over records
    mapping(address => EnumerableSet.Bytes32Set) internal userCollections;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyRecordOwner(bytes32 collectionId) {
        require(records[collectionId].owner == msg.sender, "Ownable: caller is not the record owner");
        _;
    }

    /**
     * @dev Adds a new record for a collection.
     * @param collectionId_ The new collection to set.
     * @param owner_ The address of the owner.
     * @param collectionAddress_ The address of the collection contract.
     */
    function registerCollection(bytes32 collectionId_, string calldata name_, address owner_, address collectionAddress_) external virtual override {
        require(!recordExists(collectionId_), "Collection already exists");
        _setOwner(collectionId_, owner_);
        _setAddress(collectionId_, collectionAddress_);
        records[collectionId_].name = name_;
        emit NewCollection(collectionId_, name_, owner_, collectionAddress_);
    }

    /**
     * @dev Transfers ownership of a collection to a new address. May only be called by the current owner of the node.
     * @param collectionId_ The collection to transfer ownership of.
     * @param owner_ The address of the new owner.
     */
    function setOwner(bytes32 collectionId_, address owner_) external virtual override onlyRecordOwner(collectionId_) {
        _setOwner(collectionId_, owner_);
        emit TransferOwnership(collectionId_, owner_);
    }

    /**
    * @dev Sets the address for the specified collection.
    * @param collectionId_ The collection to update.
    * @param address_ The address of the collection.
    */
    function setAddress(bytes32 collectionId_, address address_) external virtual override onlyRecordOwner(collectionId_) {
        emit NewAddress(collectionId_, address_);
        records[collectionId_].addr = address_;
    }

    /**
    * @dev Returns the address that owns the specified node.
    * @param collectionId_ The specified node.
    * @return address of the owner.
    */
    function ownerOf(bytes32 collectionId_) external virtual override view returns (address) {
        address addr = records[collectionId_].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
    * @dev Returns the collection address for the specified collection.
    * @param collectionId_ The specified collection.
    * @return address of the collection.
    */
    function addressOf(bytes32 collectionId_) external virtual override view returns (address) {
        return records[collectionId_].addr;
    }

    /**
    * @dev Returns whether a record has been imported to the registry.
    * @param collectionId_ The specified node.
    * @return Bool if record exists.
    */
    function recordExists(bytes32 collectionId_) public virtual override view returns (bool) {
        return records[collectionId_].owner != address(0x0);
    }


    struct RecordWithId{
        address addr;
        string name;
        bytes32 id;
    }

    /**
    * @dev Returns a list of all available user collections.
    * @param userAddress_ The specified user.
    * @return A list of RecordWithId
    */
    function listCollections(address userAddress_) external view returns (RecordWithId[] memory) {
        bytes32[] memory _collectionIds = userCollections[userAddress_].values();
        RecordWithId[] memory _recordsResult = new RecordWithId[](_collectionIds.length);
        for (uint256 i = 0; i < _collectionIds.length; i++) {
            _recordsResult[i].addr = records[_collectionIds[i]].addr;
            _recordsResult[i].name = records[_collectionIds[i]].name;
            _recordsResult[i].id = _collectionIds[i];
        }
        return _recordsResult;
    }


    function _setOwner(bytes32 collectionId_, address owner_) internal virtual {
        address prevOwner = records[collectionId_].owner;
        if (prevOwner != address(0x0)) {
            userCollections[prevOwner].remove(collectionId_);
        }

        userCollections[owner_].add(collectionId_);
        records[collectionId_].owner = owner_;
    }

    function _setAddress(bytes32 collectionId_, address collectionAddress_) internal {
        records[collectionId_].addr = collectionAddress_;
    }

}