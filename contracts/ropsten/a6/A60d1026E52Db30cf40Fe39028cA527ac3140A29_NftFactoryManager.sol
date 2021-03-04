// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./NftFactory.sol";

import "hardhat/console.sol";

contract NftFactoryManager is ERC1155Receiver {

    NftFactory public nftFactory;
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Represents an address' ownership of a particular moment (ERC1155 token) wiith a unique # mint number.
    struct Moment {
        address owner;
        string URI;
        bool forSale;

        uint tokenID;
        uint mintNumber;

        uint price;
    }

    /// @notice Represents the state of a particular moment (ERC1155 token). 
    struct MomentClass {
        address creator;
        string URI;

        uint tokenID;
        uint totalSupply;
        uint momentsPacked;
    }

    /// @notice Simulates an array of Moment structs.
    struct MomentsArray {
        // Index => moment
        mapping(uint => Moment) moments;

        // Token ID => ( Mint number => key in moments mapping )
        mapping(uint => mapping(uint => uint)) keys;

        uint size;
        EnumerableSet.UintSet deletedIndices;
    }

    /// @notice Stores convenience facts and mappings for moments.
    struct MomentRecord {
        // Token ID => moment class struct.
        mapping(uint => MomentClass) momentClass; 

        // Token ID => ( # Mint number => moment struct )
        mapping(uint => mapping(uint => Moment)) moments;

        // Address => token IDs of moments (ERC 1155) owned by address  
        mapping(address => EnumerableSet.UintSet) address_to_IDsOwned;

        // Address => Array of all moments owned and once owned by this address.
        mapping(address => MomentsArray)  address_to_momentsOwned;
    }

    /// @notice Represents the state of a pack, and an address' ownership of it.
    struct Pack {
        address owner;
        uint id;
        uint[] momentIDs;
        uint price;
    }

    /// @notice Stores convenience facts and mappings for packs.
    struct PackRecord {
        uint packsMinted;

        // Pack ID => moments in pack.
        mapping(uint => MomentsArray) momentsInPack;

        // Pack ID => pack. 
        mapping(uint => Pack) packID_to_pack;
    }

    PackRecord public packRecord;
    MomentRecord momentRecord;
    
    event MomentClassUpdate(uint indexed _momentID, MomentClass _moment);
    event MomentTokenUpdate(uint indexed _momentID, address indexed _owner, Moment _moment);

    event PackCreated(uint indexed _packID);
    event PackStateUpdate(uint indexed _packID);

    constructor(address _nftFactory) ERC1155Receiver() {
        // set NftFactory (ERC 1155 token contract)
        nftFactory = NftFactory(_nftFactory);

        // init records
        packRecord.packsMinted = 0;
    }

    /// @notice Mints a given amount of ERC 1155 tokens -- moment tokens. Creates a moment class for the moment.
    /// @param _URI The URI storing all moment related data.
    /// @param _amount The initial supply of the moment, on mint.
    /// @param _creator The creator of the URI content associated with the moment.
    function mintMoment(
        string calldata _URI,
        uint _amount,
        address _creator
    ) external returns (uint _id) {

        _id = nftFactory.mintMoment(_URI, _amount);

        MomentClass memory momentClass = MomentClass({
            creator: _creator,
            URI: _URI,
            tokenID: _id,
            totalSupply: _amount,
            momentsPacked: 0
        });
        momentRecord.momentClass[_id] = momentClass;
        
        emit MomentClassUpdate(_id, momentRecord.momentClass[_id]);
    }

    /// @notice Increases the supply of an already minted moment.
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    /// @param _amount The amount by which to increase the supply of the moment.
    function increaseMomentSupply(uint _momentID, uint _amount) external returns (uint totalSupplyOfMoment) {
        nftFactory.increaseMomentSupply(_momentID, _amount);
        momentRecord.momentClass[_momentID].totalSupply += _amount;

        totalSupplyOfMoment = momentRecord.momentClass[_momentID].totalSupply;
    }

    /// @notice Creates a pack containing a given set of moments.
    /// @param _momentIDs The set of token IDs of the moments that the pack is to be populated with.
    /// @param _price The price of the pack.
    function createPack(uint[] calldata _momentIDs, uint _price) public {
        
        require(_momentIDs.length == 3, "Can only create packs of size 3.");

        packRecord.packsMinted += 1;
        uint packID = packRecord.packsMinted;

        Pack memory pack = Pack({
            owner: address(this),
            id: packID,
            momentIDs: _momentIDs,
            price: _price
        });
        packRecord.packID_to_pack[packID] = pack;

        populatePack(packID, _momentIDs);

        emit PackCreated(packID);
    }

    /// @notice Populates a pack i.e. associates the packID with an array of moment structs in the pack records.
    /// @param _packID The unique ID of the pack.
    /// @param _momentIDs The set of token IDs of the moments that the pack is to be populated with.
    function populatePack(uint _packID, uint[] calldata _momentIDs) internal {
        MomentsArray storage packMoments = packRecord.momentsInPack[_packID];
        
        uint step = packMoments.size;
        packMoments.size += _momentIDs.length;

        for(uint i = 0; i < _momentIDs.length; i++) {
            packMoments.moments[i + step] = publishMoment(_momentIDs[i]);
        }
    }

    /// @notice Assigns a # mint number to a moment token (e.g. the nth token out of the x amount of tokens minted for that moment)
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    function publishMoment(uint _momentID) internal returns (Moment memory moment) {

        MomentClass memory momentClass = momentRecord.momentClass[_momentID];
        
        momentClass.momentsPacked += 1;
        uint momentMintNumber = momentClass.momentsPacked;

        moment = Moment({
            owner: address(this),
            URI: momentClass.URI,
            forSale: false,

            tokenID: _momentID,
            mintNumber: momentMintNumber,

            price: 0
        });

        momentRecord.moments[_momentID][momentMintNumber] = moment;
        momentRecord.momentClass[_momentID] = momentClass;

        emit MomentTokenUpdate(_momentID, moment.owner, moment);
    }

    /// @notice Lets a user buy a pack, once created.
    /// @param _packID The unique ID of the pack to purchase.
    function buyPack(uint _packID) public payable {

        require(_packID > 0 && _packID <= packRecord.packsMinted, "Can only buy a pack that's minted.");

        Pack storage pack = packRecord.packID_to_pack[_packID];
        require(pack.owner == address(this), "Can only buy a pack not already bought.");
        require(msg.value == pack.price, "Value sent must be at least as great as the pack price.");

        // Distribute funds per specification. Then -->
        nftFactory.transferPack(pack.owner, msg.sender, pack.momentIDs);
        pack.owner = msg.sender;

        // Update Moment record (apologies for the looong function name)
        updateRecordsOnPackPurchase(msg.sender, pack.id);

        emit PackStateUpdate(_packID);
    }

    /// @notice Updates the mappings in the Moment record upon a pack purchase.
    /// @param _caller The new owner address of the pack.
    /// @param _packID The unique ID of the pack to purchase.
    function updateRecordsOnPackPurchase(address _caller, uint _packID) internal {
        
        MomentsArray storage momentsInPack = packRecord.momentsInPack[_packID];
        EnumerableSet.UintSet storage momentIDsHeldByUser = momentRecord.address_to_IDsOwned[_caller];
        MomentsArray storage momentsHeldByUser = momentRecord.address_to_momentsOwned[_caller];

        for(uint i = 0; i < momentsInPack.size; i++) {
            Moment memory moment = momentsInPack.moments[i];
            moment.owner = _caller;

            EnumerableSet.add(momentIDsHeldByUser, moment.tokenID);
            
            momentsHeldByUser.moments[momentsHeldByUser.size] = moment;
            momentsHeldByUser.keys[moment.tokenID][moment.mintNumber] = momentsHeldByUser.size;
            momentsHeldByUser.size += 1;

            momentRecord.moments[moment.tokenID][moment.mintNumber] = moment;

            emit MomentTokenUpdate(moment.tokenID, moment.owner, moment);
        }
        
    }

    /// @notice Lets a user buy a moment owned by a different user.
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    /// @param _mintNumber  The mint number of a moment token (e.g. the nth token out of the x amount of tokens minted for that moment)
    function buyMoment(uint _momentID, uint _mintNumber) public payable {
        Moment memory moment = momentRecord.moments[_momentID][_mintNumber];
        require(msg.value == moment.price, "Must pay exactly the price of the moment to buy the moment.");

        nftFactory.transferSingleMoment(moment.owner, msg.sender, moment.tokenID);
        address prevOwner = moment.owner;
        moment.owner = msg.sender;

        // `moments` mapping
        momentRecord.moments[_momentID][_mintNumber] = moment;

        // `address_to_IDsOwned` mapping
        EnumerableSet.remove(momentRecord.address_to_IDsOwned[prevOwner], moment.tokenID);
        EnumerableSet.add(momentRecord.address_to_IDsOwned[moment.owner], moment.tokenID);

        // `address_to_momentsOwned` mapping
        MomentsArray storage momentsHeldByPrevOwner = momentRecord.address_to_momentsOwned[prevOwner];
        uint keyToDelete = momentsHeldByPrevOwner.keys[moment.tokenID][moment.mintNumber];
        EnumerableSet.add(momentsHeldByPrevOwner.deletedIndices, keyToDelete);
        momentsHeldByPrevOwner.moments[keyToDelete] = moment;

        MomentsArray storage momentsHeldByNewOwner = momentRecord.address_to_momentsOwned[moment.owner];
        uint key = momentsHeldByNewOwner.size;
        momentsHeldByNewOwner.size += 1;
        momentsHeldByNewOwner.moments[key] = moment;

        emit MomentTokenUpdate(moment.tokenID, moment.owner, moment);
    }

    /// @notice Allows the owner of a moment to set moment price.
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    /// @param _mintNumber The mint number of a moment token (e.g. the nth token out of the x amount of tokens minted for that moment)
    /// @param _newPrice The new price of the moment that is to be set.
    function setMomentPrice(uint _momentID, uint _mintNumber, uint _newPrice) public {
        Moment memory moment = momentRecord.moments[_momentID][_mintNumber];
        require(msg.sender == moment.owner, "Only the owner can change the price of the moment.");
        
        moment.price = _newPrice; 

        // Update `moments` mapping
        momentRecord.moments[_momentID][_mintNumber] = moment;

        // Update `address_to_momentsOwned` mapping
        MomentsArray storage momentsHeldByNewOwner = momentRecord.address_to_momentsOwned[moment.owner];
        uint key = momentsHeldByNewOwner.keys[moment.tokenID][moment.mintNumber];
        momentsHeldByNewOwner.moments[key] = moment;

        emit MomentTokenUpdate(moment.tokenID, moment.owner, moment);
    }

    function setMomentSaleStatus(uint _momentID, uint _mintNumber, uint _newPrice, bool _forSale) public {
        Moment memory moment = momentRecord.moments[_momentID][_mintNumber];
        require(msg.sender == moment.owner, "Only the owner can change the status of the moment.");

        moment.price = _newPrice; 
        moment.forSale = _forSale;

        // Update `moments` mapping
        momentRecord.moments[_momentID][_mintNumber] = moment;

        // Update `address_to_momentsOwned` mapping
        MomentsArray storage momentsHeldByNewOwner = momentRecord.address_to_momentsOwned[moment.owner];
        uint key = momentsHeldByNewOwner.keys[moment.tokenID][moment.mintNumber];
        momentsHeldByNewOwner.moments[key] = moment;

        emit MomentTokenUpdate(moment.tokenID, moment.owner, moment);
    }
    
    /// @notice Gets the moment having a particular momentID and mintNumber. 
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    /// @param _mintNumber The mint number of a moment token (e.g. the nth token out of the x amount of tokens minted for that moment)
    function getMoment(uint _momentID, uint _mintNumber) public view returns (Moment memory moment) {
        moment = momentRecord.moments[_momentID][_mintNumber];
    }

    /// @notice Gets the moment class associated with a particular momentID. 
    /// @param _momentID The unique token ID of a moment through which the ERC 1155 identifies the moment.
    function getMomentClass(uint _momentID) public view returns (MomentClass memory momentClass) {
        momentClass = momentRecord.momentClass[_momentID];
    }

    /// @notice Gets all moments currently and previously owned by an address.
    /// @dev The gas consumption of the function is unpredictable. Consider parsing event logs to get all moments of an address.
    /// @param _holder The address whose moments are to be returned.
    function getAllMomentsOwned(address _holder) public view returns (Moment[] memory moments){

        MomentsArray storage momentsArray = momentRecord.address_to_momentsOwned[_holder];
        
        uint momentsSize = 0;
        for(uint i = 0; i < momentsArray.size; i++) {
            if(momentsArray.moments[i].owner == _holder) {
                momentsSize += 1;
            }
        }
        uint[] memory momentsIndices = new uint[](momentsSize);
        uint indexCount = 0;
        for(uint i = 0; i < momentsArray.size; i++) {
            if(momentsArray.moments[i].owner == _holder) {
                momentsIndices[indexCount] = i;
                indexCount += 1;
            }
        }

        moments = new Moment[](momentsIndices.length);
        for(uint i = 0; i < momentsIndices.length; i++) {
            uint index = momentsIndices[i];
            moments[i] = momentsArray.moments[index];
        }
    
    }

    /// @notice Gets all momentIDs owned by an address;
    /// @dev The gas consumption of the function is unpredictable. Consider parsing event logs to get all moments of an address.
    /// @param _holder The address whose moments are to be returned.
    function getMomentIDsByAddress(address _holder) public view returns (uint[] memory ids) {
        
        uint size = EnumerableSet.length(momentRecord.address_to_IDsOwned[_holder]);
        ids= new uint[](size);

        for(uint i = 0; i < size; i++) {
            ids[i] = EnumerableSet.at(momentRecord.address_to_IDsOwned[_holder], i);
        }
    }

    /// @notice Get the pack associated with the given pack ID.
    /// @param _packID The unique ID of the pack to be retrieved.
    function getPack(uint _packID) public view returns (Pack memory pack) {
        pack = packRecord.packID_to_pack[_packID];
    }

    // ERC1155 Receiver functions

    function onERC1155Received (
        address operator,
        address from,
        uint id,
        uint value,
        bytes calldata data
    
    ) external pure override returns (bytes4) {
        // TBD
        operator;
        from;
        id;
        value;
        data;
        
        // Return val. according to ERC 1155 standard
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived (
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    
    ) external pure override returns(bytes4) {
        // TBD
        operator;
        from;
        ids;
        values;
        data;

        // Return val. according to ERC 1155 standard
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }  
}