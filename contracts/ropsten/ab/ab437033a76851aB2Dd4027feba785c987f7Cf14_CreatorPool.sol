// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NftFactoryManager.sol";

contract CreatorPool {

    using SafeMath for uint; 

    NftFactoryManager public nftFactoryManager;
    IERC20 public DAI;

    struct BlockBook {
        // Moment ID => Mint number => Block of purchase
        mapping(uint => mapping(uint => uint)) moment_to_blockOfReference;

        uint numberOfMoments;
        uint sumOfBlocksPassed;
        uint blockAtSumUpdate;
    }

    uint public protocolReserves;
    // Address of creator => Creator pool
    mapping(address => uint) public pool;
    // Address of creator => Creator pool's share tracker / block book.
    mapping(address => BlockBook) public poolBlockBook;
    
    constructor(address _daiAddress) {
        // DAI = IERC20(0xaD6D458402F60fD3Bd25163575031ACDce07538D); // DAI address on Ropsten test net.
        DAI = IERC20(_daiAddress);
    }

    function setFactoryManager(address _newManager) public {
        require(address(nftFactoryManager) == address(0) || address(nftFactoryManager) == msg.sender, "Only the factor manager can call the factory");
        nftFactoryManager = NftFactoryManager(_newManager);
    }

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == address(nftFactoryManager), "Only the factor manager can call the factory");
        _;
    }

    // ===== Time =====

    /// @notice Called on 1) ERC 1155 transfer of moment token, and 2) withdrawal of moment token's share in pool.
    function updateBlockBook(address _creator, uint _momentID, uint _mintNumber) public returns (uint) {

        require(
           nftFactoryManager.getMomentCreator(_momentID) == _creator, 
            "A moment has share only in its creator's pool."
        );
        require(
            nftFactoryManager.totalSupplyOfMoment(_momentID) >= _mintNumber, 
            "Only moments that are minted have a share in creator pools."
        );

        if(poolBlockBook[_creator].moment_to_blockOfReference[_momentID][_mintNumber] == 0) {
            poolBlockBook[_creator].moment_to_blockOfReference[_momentID][_mintNumber] = block.number;
            poolBlockBook[_creator].numberOfMoments += 1;
            
        } else {

            // Add the time passed since last update
            uint factor = poolBlockBook[_creator].numberOfMoments;
            uint timePassed = block.number - poolBlockBook[_creator].blockAtSumUpdate;
            poolBlockBook[_creator].sumOfBlocksPassed += (timePassed*factor);

            // Reset the moment's share upon a state changing action i.e. a transfer or withdrawal.
            uint prevBlockOfReference = poolBlockBook[_creator].moment_to_blockOfReference[_momentID][_mintNumber];
            uint diff = block.number - prevBlockOfReference;
            
            poolBlockBook[_creator].sumOfBlocksPassed -= diff;
            poolBlockBook[_creator].moment_to_blockOfReference[_momentID][_mintNumber] = block.number;
        }

        poolBlockBook[_creator].blockAtSumUpdate = block.number;

        return poolBlockBook[_creator].sumOfBlocksPassed;
    }

    // 0.90 || 0.09 || 0.009 || 0.0009 || 0.0001 -- 4 decimal system
    enum Rarity {Common, Uncommon, Rare, SuperRare, Legendary}

    /// @notice Calculates share of moment token in the pool
    function getShareInPool(address _creator, uint _momentID, uint _mintNumber) public view returns (uint share) {

        uint rarity = nftFactoryManager.getMomentRarity(_momentID, _mintNumber);
        uint blockOfReference = poolBlockBook[_creator].moment_to_blockOfReference[_momentID][_mintNumber];

        uint addressablePool = getPoolByRarity(rarity, pool[_creator]);
        uint factor = poolBlockBook[_creator].numberOfMoments;
        uint timePassed = block.number - poolBlockBook[_creator].blockAtSumUpdate;
        uint  sumOfBlocksPassed = poolBlockBook[_creator].sumOfBlocksPassed + (timePassed*factor);

        share = (addressablePool * (block.number - blockOfReference))/ sumOfBlocksPassed;
    }

    /// @notice Let's moment holder withdraw a moment's share in a creator pool
    function withdrawShareInPool(address _creator, uint[] calldata _momentIDs, uint[] calldata _mintNumbers) public {

        require(_momentIDs.length == _mintNumbers.length, "Must send the same amount of ids as mint numbers.");

        uint shareToWithdraw;
        for(uint i = 0; i < _momentIDs.length; i++) {

            require(
                msg.sender == nftFactoryManager.getMomentOwner(_momentIDs[i], _mintNumbers[i]),
                "Only the owner of the moment token can withdraw its share in the pool."
            );
            // SAFE MATH CHECK +=
            shareToWithdraw += getShareInPool(_creator, _momentIDs[i], _mintNumbers[i]);
            updateBlockBook(_creator, _momentIDs[i], _mintNumbers[i]);
        }        
        // SAFE MATH CHECK -=
        pool[_creator] -= shareToWithdraw;
        DAI.approve(address(this), shareToWithdraw);
        DAI.transferFrom(address(this), msg.sender, shareToWithdraw);
    }

    /// @notice Get the pool share entitled to the rarity category
    function getPoolByRarity(uint _rarity, uint _pool) public pure returns (uint poolByRarity) {

        if(_rarity == uint(Rarity.Common)) {
            poolByRarity = (_pool*1)/(10**4);
        
        } else if (_rarity == uint(Rarity.Uncommon)) {
            poolByRarity = (_pool*9)/(10**4);

        } else if (_rarity == uint(Rarity.Rare)) {
            poolByRarity = (_pool*90)/(10**4);
            
        } else if (_rarity == uint(Rarity.SuperRare)) {
            poolByRarity = (_pool*900)/(10**4);
            
        } else if (_rarity == uint(Rarity.Legendary)) {
            poolByRarity = (_pool*9000)/(10**4);
            
        } else {
            revert("The moment has invalid rarity. This should be impossible.");
        }
    }

    // ===== Pack Purchase =====

    function onPackPurchase(
        uint _packValue, 
        address _creator
    ) external OnlyFactoryManager(msg.sender) {
        require(DAI.balanceOf(address(this)) >= _packValue, "Not enough balance in the pool contract to pay people.");

        // Pay creator
        uint creatorCut = getCut(_packValue, creatorCutOfPackSale);

        DAI.approve(address(this), creatorCut);
        DAI.transferFrom(address(this), _creator, creatorCut);
        // Pay pool
        pool[_creator] += getCut(_packValue, poolCutOfPackSale);
    }

    // ===== Moment Resale =====

    function onMomentTransfer(
        uint _momentValue,
        address _creator,
        address _prevOwner
    ) external OnlyFactoryManager(msg.sender) {
        require(DAI.balanceOf(address(this)) >= _momentValue, "Not enough balance in the pool contract to pay people.");
        
        uint feeValue = getCut(_momentValue, resaleTransactionFee);
        
        // Pay previous owner of moment
        DAI.approve(address(this), _momentValue - feeValue);
        DAI.transferFrom(address(this), _prevOwner, _momentValue - feeValue);
        
        // Pay network:

        // Pay creator
        uint value = getCut(feeValue, creatorCutOfTransactionFee);
        DAI.approve(address(this), value);
        DAI.transferFrom(address(this), _creator, value);
        // Pay pool
        pool[_creator] = pool[_creator] + getCut(feeValue, poolCutOfTransactionFee);
        // Pay protocol
        protocolReserves += getCut(feeValue, protocolCutOfTransactionFee);
    }

    // Distribution parameters

    uint public creatorCutOfPackSale; // 80 %
    uint public poolCutOfPackSale; // 20 %

    uint public resaleTransactionFee; // 6 %
    
    // 2 % each (resaleFee / 3)
    uint public creatorCutOfTransactionFee; 
    uint public poolCutOfTransactionFee; 
    uint public protocolCutOfTransactionFee; 

    // Setters (caller whitelist / other restrictions not set)
    
    function setSharesOfPackSale(uint _newCreatorCut, uint _newCommunityCut) public {
        require(_newCreatorCut + _newCommunityCut <= 100, "Cuts must add up to a 100 percent.");
        creatorCutOfPackSale = _newCreatorCut; // 80
        poolCutOfPackSale = _newCommunityCut; // 20
    }

    function setResaleTransactionFee(uint _newTransactionFee) public {
        require(_newTransactionFee <= 100, "Cannot take more than 100 percent as transaction fee.");
        resaleTransactionFee = _newTransactionFee; // 6
    }

    function setSharesOfTransactionFees(
        uint _newCreatorCut,
        uint _newCommunityCut,
        uint _newProtocolCut
    ) public {
        require(_newCreatorCut + _newCommunityCut + _newProtocolCut <= 100, "Cuts must add up to a 100 percent.");

        creatorCutOfTransactionFee = _newCreatorCut; // 34
        poolCutOfTransactionFee = _newCommunityCut; // 33
        protocolCutOfTransactionFee = _newProtocolCut; // 33        
    }

    // Getters

    function getCut(uint _value, uint _percentage) public pure returns (uint cut) {
        cut = (_value * _percentage)/(10**2);
    }

    function getNumOfMomentsInBlockBook(address _creator) public view returns (uint numOfMoments) {
        numOfMoments = poolBlockBook[_creator].numberOfMoments;
    }

}