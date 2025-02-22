// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./interfaces/IDeFiatGov.sol";
import "./utils/DeFiatUtils.sol";

contract DeFiatGov is IDeFiatGov, DeFiatUtils {
    event RightsUpdated(address indexed caller, address indexed subject, uint256 level);
    event RightsRevoked(address indexed caller, address indexed subject);
    event MastermindUpdated(address indexed caller, address indexed subject);
    event FeeDestinationUpdated(address indexed caller, address feeDestination);
    event TxThresholdUpdated(address indexed caller, uint256 txThreshold);
    event BurnRateUpdated(address indexed caller, uint256 burnRate);
    event FeeRateUpdated(address indexed caller, uint256 feeRate);

    address public override mastermind;
    mapping (address => uint256) private actorLevel; // governance = multi-tier level
    
    address private feeDestination; // target address for fees
    uint256 private txThreshold; // min dft transferred to mint dftp
    uint256 private burnRate; // % burn on each tx, 10 = 1%
    uint256 private feeRate; // % fee on each tx, 10 = 1% 

    modifier onlyMastermind {
        require(msg.sender == mastermind, "Gov: Only Mastermind");
        _;
    }

    modifier onlyGovernor {
        require(actorLevel[msg.sender] >= 2,"Gov: Only Governors");
        _;
    }

    modifier onlyPartner {
        require(actorLevel[msg.sender] >= 1,"Gov: Only Partners");
        _;
    }

    constructor() public {
        mastermind = msg.sender;
        actorLevel[mastermind] = 3;
        feeDestination = mastermind;
    }
    
    // VIEW

    // Gov - Actor Level
    function viewActorLevelOf(address _address) public override view returns (uint256) {
        return actorLevel[_address];
    }

    // Gov - Fee Destination / Treasury
    function viewFeeDestination() public override view returns (address) {
        return feeDestination;
    }

    // Points - Transaction Threshold
    function viewTxThreshold() public override view returns (uint256) {
        return txThreshold;
    }

    // Token - Burn Rate
    function viewBurnRate() public override view returns (uint256) {
        return burnRate;
    }

    // Token - Fee Rate
    function viewFeeRate() public override view returns (uint256) {
        return feeRate;
    }

    // Governed Functions

    // Update Actor Level, can only be performed with level strictly lower than msg.sender's level
    // Add/Remove user governance rights
    function setActorLevel(address user, uint256 level) public {
        require(level < actorLevel[msg.sender], "ActorLevel: Can only grant rights below you");
        require(actorLevel[user] < actorLevel[msg.sender], "ActorLevel: Can only update users below you");

        actorLevel[user] = level; // updates level -> adds or removes rights
        emit RightsUpdated(msg.sender, user, level);
    }
    
    // MasterMind - Revoke all rights
    function removeAllRights(address user) public onlyMastermind {
        require(user != mastermind, "Mastermind: Cannot revoke own rights");

        actorLevel[user] = 0; 
        emit RightsRevoked(msg.sender, user);
    }

    // Mastermind - Transfer ownership of Governance
    function setMastermind(address _mastermind) public onlyMastermind {
        require(_mastermind != mastermind, "Mastermind: Cannot call self");

        mastermind = _mastermind; // Only one mastermind
        actorLevel[_mastermind] = 3;
        actorLevel[mastermind] = 2; // new level for previous mastermind
        emit MastermindUpdated(msg.sender, mastermind);
    }

    // Gov - Update the Fee Destination
    function setFeeDestination(address _feeDestination) public onlyGovernor {
        require(_feeDestination != feeDestination, "FeeDestination: No destination change");

        feeDestination = _feeDestination;
        emit FeeDestinationUpdated(msg.sender, feeDestination);
    }

    // Points - Update the Tx Threshold
    function changeTxThreshold(uint _txThreshold) public onlyGovernor {
        require(_txThreshold != txThreshold, "TxThreshold: No threshold change");

        txThreshold = _txThreshold;
        emit TxThresholdUpdated(msg.sender, txThreshold);
    }
    
    // Token - Update the Burn Rate
    function changeBurnRate(uint _burnRate) public onlyGovernor {
        require(_burnRate <= 200, "BurnRate: 20% limit");

        burnRate = _burnRate; 
        emit BurnRateUpdated(msg.sender, burnRate);
    }

    // Token - Update the Fee Rate
    function changeFeeRate(uint _feeRate) public onlyGovernor {
        require(_feeRate <= 200, "FeeRate: 20% limit");

        feeRate = _feeRate;
        emit FeeRateUpdated(msg.sender, feeRate);
    }
}