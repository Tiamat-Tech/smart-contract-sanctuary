// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

import "./NftFactory.sol";
import "./CreatorPool.sol";
import "./MomentState.sol";

contract NftFactoryManager {

    using EnumerableSet for EnumerableSet.UintSet;
    using MomentState for MomentState.Moment;
    using MomentState for MomentState.MomentStore;
    using MomentState for MomentState.Pack;

    NftFactory public nftFactory;
    CreatorPool public creatorPool;
    
    uint public nextMomentID;
    uint public nextPackID;

    mapping(string => uint) public URI_to_momentID;
    mapping(uint => uint) public totalSupplyOfMoment;

    mapping(address => EnumerableSet.UintSet) momentIDsOwned;
    mapping(address => mapping(uint => EnumerableSet.UintSet)) momentMintNumbers;
    mapping(uint => MomentState.MomentStore) public momentStore;

    mapping(uint => MomentState.Pack) public packID_to_pack;

    event MomentMinted(uint indexed momentID, address indexed owner, uint amount);
    event MomentPublished(uint indexed momentID, uint indexed mintNumber);
    event MomentTransfer(uint indexed momentID, address indexed from, address indexed to, MomentState.Moment moment);

    event PackMinted(uint packID, address indexed creator);
    event PackSold(uint packID, address indexed creator, address indexed to);

    constructor(address _nftFactory, address _creatorPool) {
        nftFactory = NftFactory(_nftFactory);
        creatorPool = CreatorPool(_creatorPool);

        nextMomentID = 1;
        nextPackID = 1;
    }

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == address(nftFactory), "Only the factor manager can call the factory");
        _;
    }

     /// @notice Mints a given amount of ERC 1155 tokens -- moment tokens -- and updates state accordingly.
    function mintMoment(
        string calldata _URI,
        uint _amount,
        address payable _creator
    ) public returns (uint momentID) {

        // Update application state
        momentID = assignMomentID(_URI);
        
        EnumerableSet.add(momentIDsOwned[_creator], momentID);
        MomentState.onMomentMint(
            momentStore[momentID],
            momentID,
            _URI,
            _creator
        );
        
        // Call NFT Factory
        increaseMomentSupply(momentID, _amount);

        // Call creator pool
        if(!creatorPool.getPoolStatus(_creator)) creatorPool.initPool(_creator);

        emit MomentMinted(momentID, _creator, _amount);
    }

    function publishMoment(uint _momentID) internal returns(uint mintNumber) {

        mintNumber = MomentState.onPublishMoment(
            momentStore[_momentID],
            _momentID,
            momentStore[_momentID].URI,
            momentStore[_momentID].creator
        );
        
        EnumerableSet.add(momentMintNumbers[momentStore[_momentID].creator][_momentID], mintNumber);

        emit MomentPublished(_momentID, mintNumber);
    }

    /// @notice Increases the supply of a moment.
    function increaseMomentSupply(uint _momentID, uint _amount) public {
        require(_momentID < nextMomentID, "Can only change the status of an existing moment token.");

        totalSupplyOfMoment[_momentID] =  totalSupplyOfMoment[_momentID] + _amount;
        nftFactory.mint(momentStore[_momentID].creator, _momentID, _amount, "");
    }

    /// @notice A helper function that assigns a moment ID to a newly minted moment.
    function assignMomentID(string memory _URI) internal returns (uint id) {
        require(URI_to_momentID[_URI] == 0, "Cannot double mint the same URI.");

        id = nextMomentID;
        URI_to_momentID[_URI] = id;

        nextMomentID += 1;
    }

    /// @notice Creates a pack containing a given set of moments.
   function createPack (
       uint[] calldata _momentIDs, 
       uint _price
    ) external {

        uint packID = nextPackID;
        nextPackID++;

        address creator;
        uint[] memory mintNumbers = new uint[](_momentIDs.length);
        for(uint i = 0; i < _momentIDs.length; i++) {
            require(_momentIDs[i] < nextMomentID, "A moment that's not minted cannot be packed");
           
            creator = momentStore[_momentIDs[i]].creator;

            require(creator == momentStore[_momentIDs[i]].creator, "A pck must have moments from the same creator.");
            require(creator != address(0), "Gotcha bitch");


            
            uint mintNumber = publishMoment(_momentIDs[i]);

            mintNumbers[i] = mintNumber;
        }

        MomentState.onPackMint(
            packID_to_pack[packID],
            creator,
            packID,
            _momentIDs,
            mintNumbers,
            _price
        );

        emit PackMinted(packID, creator);
    }

    function transferMoment(
        address _from,
        address _to,
        uint _momentID, 
        uint _mintNumber,
        bytes memory _data
    ) external payable {

        // Update application state
        MomentState.onSingleMomentTransfer(
            momentStore[_momentID],
            _to,
            _mintNumber
        );

        // Updating previous owners' moment state
        if(nftFactory.balanceOf(_from, _momentID) == 0) {
            EnumerableSet.remove(momentIDsOwned[_from], _momentID);
        }
        EnumerableSet.remove(momentMintNumbers[_from][_momentID], _mintNumber);

        // Updating new owners' moment state
        if(nftFactory.balanceOf(_to, _momentID) == 0) {
            EnumerableSet.add(momentIDsOwned[_to], _momentID);
        }
        EnumerableSet.add(momentMintNumbers[_to][_momentID], _mintNumber);

        // Call NFT Factory
        nftFactory.safeTransferFrom(_from, _to, _momentID, 1, _data);

        // Call creator pool
        creatorPool.onMomentPurchase{value: momentStore[_momentID].mintNumber_to_moment[_mintNumber].price}(
            momentStore[_momentID].mintNumber_to_moment[_mintNumber].price, 
            payable(momentStore[_momentID].creator), 
            payable(_from), 
            _to
        );

        emit MomentTransfer(_momentID, _from, _to, momentStore[_momentID].mintNumber_to_moment[_mintNumber]);
    }

    /// @notice Lets a user buy a pack.
    function transferPack(
        address _from,
        address _to,
        uint _packID
    ) external payable {

        require(_packID > 0 && _packID < nextPackID, "Can only buy a pack that's minted.");
        require(packID_to_pack[_packID].forSale, "Can only buy a pack not already bought.");
        require(packID_to_pack[_packID].owner == _from, "Cannot sell a pack if you don't own it.");
        require(msg.value == packID_to_pack[_packID].price, "Value sent must be at least as great as the pack price.");

        // Update application state
        MomentState.onPackPurchase(packID_to_pack[_packID], _to);

        // Call NFT Factory
        transferBatchOfMoments(_from, _to, packID_to_pack[_packID].momentIDs, packID_to_pack[_packID].mintNumbers, "");

        // Call creator pool
        creatorPool.onPackPurchase{value: packID_to_pack[_packID].price}(packID_to_pack[_packID].price, payable(_from), _to);

        emit PackSold(_packID, _from, _to);
    }

    /// @notice Transfers a batch of moment tokens.
    /// @dev Calls the parent ERC 1155 contract's `safeBatchTransferFrom` function
    function transferBatchOfMoments(
        address _from,
        address _to,
        uint256[] memory _momentIDs,
        uint[] memory _mintNumbers,
        bytes memory _data
    ) public {

        require(_momentIDs.length == _mintNumbers.length, "Must send both momentID and corresponding mint number.");

        uint[] memory amounts = new uint[](_momentIDs.length);
        for(uint i = 0; i < _momentIDs.length; i++) {
            
            amounts[i] = 1;
            MomentState.onSingleMomentTransfer(
                momentStore[_momentIDs[i]],
                _to,
                _mintNumbers[i]
            );
            emit MomentTransfer(_momentIDs[i], _from, _to, momentStore[_momentIDs[i]].mintNumber_to_moment[_mintNumbers[i]]);
        }

        nftFactory.safeBatchTransferFrom(_from, _to, _momentIDs, amounts, _data);
    }

    function setMomentSaleStatus(
        uint  _momentID,
        uint _mintNumber,
        uint _newPrice, 
        bool _forSale
    ) external {

        require(_momentID < nextMomentID, "Can only change the status of an existing moment token.");
        require(_mintNumber < momentStore[_momentID].nextMintNumber, "Can only change the status of an existing moment token.");

        MomentState.onSaleStatus(
            momentStore[_momentID],
            _mintNumber,
            _newPrice,
            _forSale
        );
    }

    function getMomentOwner(uint _momentID, uint _mintNumber) public view returns (address owner) {
        owner = momentStore[_momentID].mintNumber_to_moment[_mintNumber].owner;
    }
}