// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IEnvelope.sol";

contract RedEnvelope is IEnvelope {

    mapping(uint64 => Envelope) private idToEnvelopes;

    function addEnvelope(uint64 envelopeID, uint16 numParticipants, uint64[] calldata hashedPassword) payable public {
        require(idToEnvelopes[envelopeID].balance == 0, "balance not zero");
        require(msg.value > 0, "Trying to create zero balance envelope");
        Envelope storage envelope = idToEnvelopes[envelopeID];
        envelope.numParticipants = numParticipants;
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

        // claim the password
        currentEnv.passwords[passInt64].claimed = true;

        // currently withdrawl the full balance, turn this into something either true random or psuedorandom
        if (currentEnv.numParticipants == 1) {
            receiver.call{value: currentEnv.balance}("");
            currentEnv.balance = 0;
            return;
        }
        currentEnv.numParticipants--;
        uint256 moneyThisOpen = getMoneyThisOpen(receiver, currentEnv.balance);
        
        // once the withdrawal is made, mark that this password has been used
        receiver.call{value: moneyThisOpen}("");
        currentEnv.balance -= moneyThisOpen;
    }
}