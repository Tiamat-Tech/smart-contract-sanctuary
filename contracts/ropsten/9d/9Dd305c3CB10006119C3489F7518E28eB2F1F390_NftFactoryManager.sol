// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./NftFactory.sol";
import "./CreatorPool.sol";
import "./MomentState.sol";
import "./FakeDAI.sol";


contract NftFactoryManager {

    using EnumerableSet for EnumerableSet.UintSet;

    using MomentState for MomentState.Moment;
    using MomentState for MomentState.MomentStore;

    NftFactory public nftFactory;
    CreatorPool public creatorPool;
    FakeDAI public DAI;
    
    uint public nextMomentID;
    
    // 0.90 || 0.09 || 0.009 || 0.0009 || 0.0001 -- 4 decimal system
    enum Rarity {Common, Uncommon, Rare, SuperRare, Legendary}

    mapping(string => uint) public URI_to_momentID;
    mapping(uint => uint) public totalSupplyOfMoment;

    mapping(address => uint) public packPrice;

    mapping(uint => MomentState.MomentStore) public momentStore;
    mapping(address => EnumerableSet.UintSet) momentIDsOwned;
    mapping(address => EnumerableSet.UintSet) momentIDsCreated;

    event MomentUpload(uint indexed momentID, address indexed creator);
    event MomentMinted(uint indexed momentID, uint indexed mintNumber);
    event MomentTransfer(uint indexed momentID, address indexed from, address indexed to, uint price);

    event PackSold(address indexed creator, address indexed to, uint price);

    constructor(address _nftFactory, address _creatorPool, address _daiAddress) {
        nftFactory = NftFactory(_nftFactory);
        creatorPool = CreatorPool(_creatorPool);
        DAI = FakeDAI(_daiAddress);

        nextMomentID = 1;
    }

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == address(nftFactory), "Only the factor manager can call the factory");
        _;
    }

    function setFactoryManager(address _newManager) external {
        nftFactory.setFactoryManager(_newManager);
        creatorPool.setFactoryManager(_newManager);
    }

    function setFactory(address _newFactory) external {
        nftFactory = NftFactory(_newFactory);
    }

    function setCreatorPool(address _newCreatorPool) external {
        creatorPool = CreatorPool(_newCreatorPool);
    }

    function setDAI(address _daiAddress) external {
        DAI = FakeDAI(_daiAddress);
    }

    function faucet(address _to) external {
        DAI.faucet(_to);
    }

    /// @notice A helper function that assigns a moment ID to a newly minted moment.
    function assignMomentID(string memory _URI) internal returns (uint id) {
        require(URI_to_momentID[_URI] == 0, "Cannot double mint the same URI.");

        id = nextMomentID;
        URI_to_momentID[_URI] = id;

        nextMomentID += 1;
    }

    /// @notice Mints a given amount of ERC 1155 tokens -- moment tokens -- and updates state accordingly.
    function uploadMoment(string calldata _URI) public returns (uint momentID) {

        // Assign unique moment ID
        momentID = assignMomentID(_URI);
        
        // Update: 1) moment store and 2) momentIDsCreated
        EnumerableSet.add(momentIDsCreated[msg.sender], momentID);

        MomentState.onMomentUpload(
            momentStore[momentID],
            momentID,
            _URI,
            msg.sender
        );

        emit MomentUpload(momentID, msg.sender);
    }

    /// @dev The number of moment IDs in a pack is hard coded to equal three.
    /// @notice This function is pseudo-random; must be made truly random for production.
    function getRandomMomentIDs(address _creator) public view returns(uint[] memory momentIDs) {

        uint len = EnumerableSet.length(momentIDsCreated[_creator]);
        require(len >= 3, "You need to upload at least three moments to publish a pack.");

        momentIDs = new uint[](len);
        uint j = 0;

        for(uint i = len; i > (len - 3); i--) {
            
            uint id = EnumerableSet.at(
                momentIDsCreated[_creator], 
                (block.number + block.timestamp) % i
            );
            
            momentIDs[j] = id;
            j++;
        }
    }

    /// @notice The `rarity` is assigned in a pseudo random manner; must be made truly random for production.
    function getRandomRarity() public view returns (uint rarity) {
        uint slot = (block.number + block.timestamp) % (10**4); // Production formula

        if(slot < 1) {
            rarity = uint(Rarity.Legendary);
        } else if (slot < 10) {
            rarity = uint(Rarity.SuperRare);
        } else if (slot < 100) {
            rarity = uint(Rarity.Rare);
        } else if (slot < 1000) {
            rarity = uint(Rarity.Uncommon);
        } else {
            rarity = uint(Rarity.Common);
        }
    }

    /// @notice Let's a collector buy a pack.
    function buyPack(
        address _creator,
        address _to
    ) external {

        uint price = packPrice[_creator];        
        bool success = DAI.transferFrom(_to, address(creatorPool), price);
        require(success, "ERC20 transfer failed. Please approve the contract to transfer the price amount.");
        
        uint[] memory momentIDs = getRandomMomentIDs(_creator);
        uint[] memory amounts = new uint[](momentIDs.length);        

        // Update 1) momentIDsOwned and 2) Moment store
        for(uint i = 0; i < momentIDs.length; i++) {

            amounts[i] = 1;

            // Update momentIDsOwned
            EnumerableSet.add(momentIDsOwned[_to], momentIDs[i]);

            uint rarity = getRandomRarity();

            // Update Moment store
            uint mintNumber = MomentState.onMomentMint(
                momentStore[momentIDs[i]],
                _creator,
                _to,
                momentIDs[i],
                rarity
            );

            // Update total supply of moment
            totalSupplyOfMoment[momentIDs[i]] += 1;

            // Update block book in creator pool
            creatorPool.updateBlockBook(_creator, momentIDs[i], mintNumber);

            emit MomentMinted(momentIDs[i], mintNumber);
        }

        // Call nftFactory to mint moment tokens.
        nftFactory.mintBatch(_to, momentIDs, amounts, "");

        //Call creator pool
        creatorPool.onPackPurchase(price, _creator);
        emit PackSold(_creator, _to, price);
    }

    function transferMoment(
        address _from,
        address _to,
        uint _momentID, 
        uint _mintNumber
    ) external {

        require(momentStore[_momentID].moment[_mintNumber].forSale, "Can only purchase a moment that's on sale.");

        uint price = momentStore[_momentID].moment[_mintNumber].price;
        bool success = DAI.transferFrom(_to, address(creatorPool), price);
        require(success, "ERC20 transfer failed. Please approve the contract to transfer the price amount.");

        // Update application state
        MomentState.onMomentTransfer(
            momentStore[_momentID],
            _from,
            _to,
            _mintNumber
        );

        // Call NFT Factory
        nftFactory.safeTransferFrom(_from, _to, _momentID, 1, "");

        // Updating previous owners' moment state
        if(nftFactory.balanceOf(_from, _momentID) == 0) {
            EnumerableSet.remove(momentIDsOwned[_from], _momentID);
        }

        // Updating new owners' moment state
        if(nftFactory.balanceOf(_to, _momentID) == 0) {
            EnumerableSet.add(momentIDsOwned[_to], _momentID);
        }

        // Call creator pool
        creatorPool.onMomentTransfer(
            price, 
            momentStore[_momentID].creator, 
            _from
        );

        creatorPool.updateBlockBook(
            momentStore[_momentID].creator, _momentID, _mintNumber
        );

        emit MomentTransfer(_momentID, _from, _to, price);
    }

    function setMomentStatus(
        uint  _momentID,
        uint _mintNumber,
        uint _newPrice, 
        bool _forSale
    ) external {

        require(_momentID < nextMomentID, "Can only change the status of an existing moment token.");
        require(_mintNumber <= momentStore[_momentID].nextMintNumber, "Can only change the status of an existing moment token.");

        MomentState.onChangeStatus(
            momentStore[_momentID],
            _mintNumber,
            _newPrice,
            _forSale
        );
    }

    function setPackPrice(uint _newPrice) external {
        packPrice[msg.sender] = _newPrice;
    }

    function getMomentIDsOwned(address _holder) public view returns (uint[] memory momentIDs) {
        
        uint len = EnumerableSet.length(momentIDsOwned[_holder]);
        momentIDs = new uint[](len);

        for(uint i = 0; i < len; i++) {
            momentIDs[i] = EnumerableSet.at(momentIDsOwned[_holder], i);
        }
    }

    function getMintNumbersOwned(address _holder, uint  _momentID) public view returns (uint[] memory mintNumbers) {
        
        uint len = EnumerableSet.length(momentStore[_momentID].mintNumbersOwned[_holder]);
        mintNumbers = new uint[](len);

        for(uint i = 0; i < len; i++) {
            mintNumbers[i] = EnumerableSet.at(momentStore[_momentID].mintNumbersOwned[_holder], i);
        }
    }

    function getMomentIDsCreated(address _creator) public view returns (uint[] memory momentIDs) {
        uint len = EnumerableSet.length(momentIDsCreated[_creator]);
        momentIDs = new uint[](len);
        for(uint i = 0; i < len; i++) {
            uint id = EnumerableSet.at(momentIDsCreated[_creator], i);
            momentIDs[i] = id;
        }
    }

    function getMoment(uint _momentID, uint _mintNumber) public view returns (MomentState.Moment memory moment) {
        moment = momentStore[_momentID].moment[_mintNumber];
    }

    function getMomentOwner(uint _momentID, uint _mintNumber) public view returns (address owner) {
        owner = momentStore[_momentID].moment[_mintNumber].owner;
    }

    function getMomentCreator(uint _momentID) public view returns (address creator) {
        creator = momentStore[_momentID].creator;
    }

    function getMomentRarity(uint _momentID, uint _mintNumber) public view returns(uint rarity) {
        rarity = momentStore[_momentID].moment[_mintNumber].rarity;
    }
}