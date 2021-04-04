// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Manager.sol";
import "./Rarity.sol";

contract CreatorPool { 

    address public DAO;

    Manager public manager;
    Rarity public rarity;
    IERC20 public stablecoin;

    struct BlockBook {
        // Token ID => Mint number => Block of purchase
        mapping(uint => mapping(uint => uint)) token_to_blockOfReference;

        uint numberOfTokens;
        uint sumOfBlocksPassed;
        uint blockAtSumUpdate;
    }

    uint public protocolReserves;
    // Address of creator => Creator pool
    mapping(address => uint) public pool;
    // Address of creator => Creator pool's share tracker / block book.
    mapping(address => BlockBook) public poolBlockBook;
    
    constructor() {
        DAO = msg.sender;
    }

    // ===== Modifiers =====

    modifier OnlyFactoryManager(address _caller) {
        require(_caller == address(manager), "Only the factor manager can call the factory");
        _;
    }

    modifier OnlyTokenOwner(address _caller, uint _tokenID, uint _mintNumber) {
        require(
            _caller == manager.getTokenOwner(_tokenID, _mintNumber), 
            "Only the owner can change the token's properties."
        );
        _;
    }

    modifier OnlyDAO(address _caller) {
        require(
            _caller == DAO, 
            "Only the owner can change the token's properties."
        );
        _;
    }

    // ===== Config =====

    function setConfig(
        address _manager,
        address _rarity,
        address _testStablecoin
    ) external OnlyDAO(msg.sender) {

        // Set objects in contract
        manager = Manager(_manager);
        rarity = Rarity(_rarity);
        stablecoin = IERC20(_testStablecoin);
    }

    function setFactoryManager(address _newManager) public {
        require(address(manager) == address(0) || address(manager) == msg.sender, "Only the factor manager can call the factory");
        manager = Manager(_newManager);
    }

    function setDAO(address _newDAO) public {
        require(DAO == address(0) || DAO == msg.sender, "Only the factor manager can call the factory");
        DAO = _newDAO;
    }


    /// @notice Called on 1) ERC 1155 transfer of token token, and 2) withdrawal of token token's share in pool.
    function updateBlockBook(
        address _caller,
        address _creator, 
        uint _tokenID, 
        uint _mintNumber
    ) public OnlyTokenOwner(_caller, _tokenID, _mintNumber) returns (uint) {

        require(
           manager.getTokenCreator(_tokenID) == _creator, 
            "A token has share only in its creator's pool."
        );
        require(
            manager.totalSupplyOfToken(_tokenID) >= _mintNumber, 
            "Only tokens that are minted have a share in creator pools."
        );

        if(poolBlockBook[_creator].token_to_blockOfReference[_tokenID][_mintNumber] == 0) {
            poolBlockBook[_creator].token_to_blockOfReference[_tokenID][_mintNumber] = block.number;
            poolBlockBook[_creator].numberOfTokens += 1;
            
        } else {

            // Add the time passed since last update
            uint factor = poolBlockBook[_creator].numberOfTokens;
            uint timePassed = block.number - poolBlockBook[_creator].blockAtSumUpdate;
            poolBlockBook[_creator].sumOfBlocksPassed += (timePassed*factor);

            // Reset the token's share upon a state changing action i.e. a transfer or withdrawal.
            uint prevBlockOfReference = poolBlockBook[_creator].token_to_blockOfReference[_tokenID][_mintNumber];
            uint diff = block.number - prevBlockOfReference;
            
            poolBlockBook[_creator].sumOfBlocksPassed -= diff;
            poolBlockBook[_creator].token_to_blockOfReference[_tokenID][_mintNumber] = block.number;
        }

        poolBlockBook[_creator].blockAtSumUpdate = block.number;

        return poolBlockBook[_creator].sumOfBlocksPassed;
    }

    /// @notice Calculates share of token token in the pool
    function getShareInPool(address _creator, uint _tokenID, uint _mintNumber) public view returns (uint share) {

        uint tokenRarity = manager.getTokenRarity(_tokenID, _mintNumber);
        uint blockOfReference = poolBlockBook[_creator].token_to_blockOfReference[_tokenID][_mintNumber];

        uint addressablePool = rarity.getPoolShareByRarity(tokenRarity, pool[_creator]);
        uint factor = poolBlockBook[_creator].numberOfTokens;
        uint timePassed = block.number - poolBlockBook[_creator].blockAtSumUpdate;
        uint  sumOfBlocksPassed = poolBlockBook[_creator].sumOfBlocksPassed + (timePassed*factor);

        share = (addressablePool * (block.number - blockOfReference))/ sumOfBlocksPassed;
    }

    /// @notice Let's token holder withdraw a token's share in a creator pool
    function withdrawShareInPool(
        address _creator, 
        uint[] calldata _tokenIDs, 
        uint[] calldata _mintNumbers
    ) public {

        require(_tokenIDs.length == _mintNumbers.length, "Must send the same amount of ids as mint numbers.");

        uint shareToWithdraw;
        for(uint i = 0; i < _tokenIDs.length; i++) {

            require(
                msg.sender == manager.getTokenOwner(_tokenIDs[i], _mintNumbers[i]),
                "Only the owner of the token token can withdraw its share in the pool."
            );
            // SAFE MATH CHECK +=
            shareToWithdraw += getShareInPool(_creator, _tokenIDs[i], _mintNumbers[i]);
            updateBlockBook(msg.sender, _creator, _tokenIDs[i], _mintNumbers[i]);
        }        
        // SAFE MATH CHECK -=
        pool[_creator] -= shareToWithdraw;
        stablecoin.approve(address(this), shareToWithdraw);
        stablecoin.transferFrom(address(this), msg.sender, shareToWithdraw);
    }

    // ===== Pack Purchase =====

    function onPackPurchase(
        uint _packValue, 
        address _creator
    ) external OnlyFactoryManager(msg.sender) {
        require(stablecoin.balanceOf(address(this)) >= _packValue, "Not enough balance in the pool contract to pay people.");

        // Pay creator
        uint creatorCut = getCut(_packValue, creatorCutOfPackSale);

        stablecoin.approve(address(this), creatorCut);
        stablecoin.transferFrom(address(this), _creator, creatorCut);
        // Pay pool
        pool[_creator] += getCut(_packValue, poolCutOfPackSale);
        // Pay Network
        protocolReserves += getCut(_packValue, protocolCutOfPackSale);
    }

    // ===== Token Resale =====

    function onTokenTransfer(
        uint _tokenValue,
        address _creator,
        address _prevOwner
    ) external OnlyFactoryManager(msg.sender) {
        require(stablecoin.balanceOf(address(this)) >= _tokenValue, "Not enough balance in the pool contract to pay people.");
        
        uint feeValue = getCut(_tokenValue, resaleTransactionFee);
        
        // Pay previous owner of token
        stablecoin.approve(address(this), _tokenValue - feeValue);
        stablecoin.transferFrom(address(this), _prevOwner, _tokenValue - feeValue);
        
        // Pay network:

        // Pay creator
        uint value = getCut(feeValue, creatorCutOfTransactionFee);
        stablecoin.approve(address(this), value);
        stablecoin.transferFrom(address(this), _creator, value);
        // Pay pool
        pool[_creator] = pool[_creator] + getCut(feeValue, poolCutOfTransactionFee);
        // Pay protocol
        protocolReserves += getCut(feeValue, protocolCutOfTransactionFee);
    }

    // Distribution parameters

    uint public creatorCutOfPackSale; // 75 %
    uint public poolCutOfPackSale; // 20 %
    uint public protocolCutOfPackSale; // 5 %

    uint public resaleTransactionFee; // 6 %
    
    // 2 % each (resaleFee / 3)
    uint public creatorCutOfTransactionFee; 
    uint public poolCutOfTransactionFee; 
    uint public protocolCutOfTransactionFee; 

    // Setters (caller whitelist / other restrictions not set)
    
    function setSharesOfPackSale(uint _newCreatorCut, uint _newCommunityCut, uint _newProtocolCut) public OnlyDAO(msg.sender) {
        require(_newCreatorCut + _newCommunityCut + _newProtocolCut == 100, "Cuts must add up to a 100 percent.");
        creatorCutOfPackSale = _newCreatorCut; // 75
        poolCutOfPackSale = _newCommunityCut; // 20
        protocolCutOfPackSale = _newProtocolCut; // 5
    }

    function setResaleTransactionFee(uint _newTransactionFee) public OnlyDAO(msg.sender) {
        require(_newTransactionFee <= 100, "Cannot take more than 100 percent as transaction fee.");
        resaleTransactionFee = _newTransactionFee; // 6
    }

    function setSharesOfTransactionFees(
        uint _newCreatorCut,
        uint _newCommunityCut,
        uint _newProtocolCut
    ) public OnlyDAO(msg.sender) {
        require(_newCreatorCut + _newCommunityCut + _newProtocolCut == 100, "Cuts must add up to a 100 percent.");

        creatorCutOfTransactionFee = _newCreatorCut; // 34
        poolCutOfTransactionFee = _newCommunityCut; // 33
        protocolCutOfTransactionFee = _newProtocolCut; // 33        
    }

    // Getters

    function getCut(uint _value, uint _percentage) public pure returns (uint cut) {
        cut = (_value * _percentage)/(10**2);
    }

    function getNumOfTokensInBlockBook(address _creator) public view returns (uint numOfTokens) {
        numOfTokens = poolBlockBook[_creator].numberOfTokens;
    }

}