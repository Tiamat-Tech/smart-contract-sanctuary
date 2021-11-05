// SPDX-License-Identifier: MIT
pragma solidity =0.8.4;

import "./SchnorrSignature.sol";

contract CommitmentCircuit is SchnorrSignature {
    mapping (uint256 => PointEC) commitmentById;    
    mapping (address => uint256) idByAddress;
    mapping (uint256 => bool) spents; // spents[id]

    event CommitmentTransferred(address indexed sender, address indexed recipient, PointEC commitment);

    constructor () {}

    function transferCommitment (
        address recipient,
        PointEC memory recipientCommitment,
        string memory message,
        PointEC memory pubKey,
        PointEC memory ecR,
        uint256 s
    ) public {
        require(SchnorrSignatureVerify(message, pubKey, ecR, s), "invalid signature");
        require( _CommitmentVerify(recipientCommitment, pubKey) , "invalid commitments");

        _CommitmentOldSpent();
        _CommitmentNewAdd(recipient, recipientCommitment);
        emit CommitmentTransferred(msg.sender, recipient, recipientCommitment);
    }

    function _CommitmentVerify (
        PointEC memory _ecCommOutput,
        PointEC memory _ecCommValid
    ) internal view 
    returns (bool) {
        uint256 _id = idByAddress[msg.sender];
        if(!spents[_id]){
            return false;
        }
        PointEC memory _ecP;
        (_ecP.x, _ecP.y) = eSub(
            commitmentById[_id].x, commitmentById[_id].y, 
            _ecCommOutput.x, _ecCommOutput.y
            );            
        return _equalPointEC(_ecP, _ecCommValid);
    }

    function _CommitmentOldSpent() internal {

        spents[idByAddress[msg.sender]] = false;
    }

    function _CommitmentNewAdd(address _newOwner, PointEC memory _commitment) internal {
        uint256 _id = block.timestamp;
        commitmentById[_id] = _commitment;
        idByAddress[_newOwner] = _id;
        spents[_id] = true;
    }

    function setCommToUser(address _user, PointEC memory _commitment) public { // todo: delete before deploy
        uint256 _id = block.timestamp;
        commitmentById[_id] = _commitment;
        idByAddress[_user] = _id;
        spents[_id] = true;
    }
}