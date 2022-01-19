// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IEnvelope.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RedEnvelope is IEnvelope, Ownable {

    mapping(uint64 => Envelope) private idToEnvelopes;

    function returnEnvelope(uint64 envelopeID) public onlyOwner {
        Envelope storage env = idToEnvelopes[envelopeID];
        require(env.balance > 0, "Balance should be larger than zero");
        address payable receiver = payable(env.creator);
        receiver.call{value: env.balance}("");
    }

    function addEnvelope(
        uint64 envelopeID,
        uint16 numParticipants,
        uint8 passLength,
        uint256 minPerOpen,
        uint64[] calldata hashedPassword
    ) payable public {
        require(idToEnvelopes[envelopeID].balance == 0, "balance not zero");
        require(msg.value > 0, "Trying to create zero balance envelope");
        validateMinPerOpen(msg.value, minPerOpen, numParticipants);

        Envelope storage envelope = idToEnvelopes[envelopeID];
        envelope.passLength = passLength;
        envelope.minPerOpen = minPerOpen;
        envelope.numParticipants = numParticipants;
        envelope.creator = msg.sender;
        for (uint i=0; i < hashedPassword.length; i++) {
            envelope.passwords[hashedPassword[i]] = initStatus();
        }
        envelope.balance = msg.value;
    }

    function openEnvelope(address payable receiver, uint64 envelopeID, string memory unhashedPassword) public {
        require(idToEnvelopes[envelopeID].balance > 0, "Envelope is empty");
        uint64 passInt64 = hashPassword(unhashedPassword);
        Envelope storage currentEnv = idToEnvelopes[envelopeID];
        Status storage passStatus = currentEnv.passwords[passInt64];
        require(passStatus.initialized, "Invalid password!");
        require(!passStatus.claimed, "Password is already used");
        require(bytes(unhashedPassword).length == currentEnv.passLength, "password is incorrect length");

        // claim the password
        currentEnv.passwords[passInt64].claimed = true;

        // currently withdrawl the full balance, turn this into something either true random or psuedorandom
        if (currentEnv.numParticipants == 1) {
            receiver.call{value: currentEnv.balance}("");
            currentEnv.balance = 0;
            return;
        }

        uint256 moneyThisOpen = getMoneyThisOpen(
            receiver,
            currentEnv.balance,
            currentEnv.minPerOpen,
            currentEnv.numParticipants);
        
        currentEnv.numParticipants--;
        receiver.call{value: moneyThisOpen}("");
        currentEnv.balance -= moneyThisOpen;
    }
}