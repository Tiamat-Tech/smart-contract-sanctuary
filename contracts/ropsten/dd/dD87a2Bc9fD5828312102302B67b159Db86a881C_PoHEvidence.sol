// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";


// This is the main building block for smart contracts.
contract PoHEvidence is Ownable {

    event Delegated(address indexed owner, address indexed delegatee);
    event EvidenceAdded(address indexed user, address indexed delegatee, uint timestamp, bytes32 evidence);

    // @notice records of all delegatees
    mapping (address => bool) internal _delegatees;

    // @notice A Evidence for recording the PoH evidence on-chain
    struct Evidence {
        address user;
        address delegatee;
        uint timestamp;
        bytes32 evidence;
    }
    
    uint32 public numEvidences;
    // @notice a mapping from user address to its evidence
    mapping(address => Evidence) public evidences;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyDelegatees() {
        require(_delegatees[_msgSender()], "PoHEvidence: caller is not a delegatee");
        _;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () Ownable() {
    }
    
    function addEvidenceDelegate(address newEvidenceDelegate) external onlyOwner {
        require(!_delegatees[newEvidenceDelegate], "delegatee already exists");
        _delegatees[newEvidenceDelegate] = true;
        emit Delegated(msg.sender, newEvidenceDelegate);
    }

    function delegateeExists(address delegatee)  external view onlyOwner returns(bool){
        return _delegatees[delegatee];
    }

    function addEvidence(address user, uint timestamp, bytes32 evidence) external onlyDelegatees {
        Evidence memory ev = evidences[user];
        require(ev.user == address(0), "an evidence already exists for this user");
        ev.user = user;
        ev.delegatee = msg.sender;
        ev.timestamp = timestamp;
        ev.evidence = evidence;
        numEvidences ++;
        emit EvidenceAdded(user, msg.sender, timestamp, evidence);
    }

    function evidenceExists(address user) external view returns(bool){
        return evidences[user].user != address(0);
    }

    function getEvidence(address user)  external view returns(address, address, uint, bytes32){
        Evidence memory ev = evidences[user];
        return (ev.user, ev.delegatee, ev.timestamp, ev.evidence);
    }
}