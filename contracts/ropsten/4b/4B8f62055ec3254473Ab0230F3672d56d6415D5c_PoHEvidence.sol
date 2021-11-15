// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";


// This is the main building block for smart contracts.
contract PoHEvidence is Ownable {

    event Delegated(address owner, address delegatee);

    // @notice records of all delegatees
    mapping (address => bool) internal _delegatees;

    // @notice A Evidence for recording the PoH evidence on-chain
    struct Evidence {
        address user;
        address delegatee;
        uint timestamp;
        bytes32 evidence;
    }
    
    uint32 numEvidences;
    mapping(address => Evidence) public evidences;

    
    function addEvidenceDelegate(address newEvidenceDelegate) external onlyOwner {
        require(!_delegatees[newEvidenceDelegate], "delegatee already exists");
        _delegatees[newEvidenceDelegate] = true;
        emit Delegated(msg.sender, newEvidenceDelegate);
    }

    function delegateeExists(address delegatee)  external view onlyOwner returns(bool exists){
        return _delegatees[delegatee];
    }

    function addEvidence(address user, address delegatee, uint timestamp, bytes32 evidence) external onlyOwner{
        Evidence memory ev = evidences[user];
        require(ev.user == address(0), "an evidence already exists for this user");
        ev.user = user;
        ev.delegatee = delegatee;
        ev.timestamp = timestamp;
        ev.evidence = evidence;
        numEvidences ++;
    }
}