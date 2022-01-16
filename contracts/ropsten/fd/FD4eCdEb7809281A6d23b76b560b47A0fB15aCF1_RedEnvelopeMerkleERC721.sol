// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IEnvelope.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


function random(uint32 number) view returns(uint32){
    return uint32(uint256(keccak256(abi.encodePacked(block.timestamp,block.difficulty,  
    msg.sender)))) % number;
}

contract RedEnvelopeMerkleERC721 is IEnvelope, Ownable, IERC721Receiver {
    using Bits for uint8;

    mapping(string => MerkleEnvelopeERC721 ) private idToEnvelopes;

    // FIXME: return nft token to the creator
    // function returnEnvelope(string calldata envelopeID) public onlyOwner {
    //     MerkleEnvelopeERC721 storage env = idToEnvelopes[envelopeID];
    //     require(env.creator == msg.sender, "We will only return to the creator!");
    //     address payable receiver = payable(env.creator);
    //     receiver.call{value: env.balance}("");
    // }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual override returns (bytes4) {
        return 0x150b7a02;
    }

    // need to be uint256 since this is the standard https://docs.openzeppelin.com/contracts/2.x/api/token/erc721#ERC721-_mint-address-uint256-
    function addEnvelope(
        string calldata envelopeID,
        bytes32 hashedMerkelRoot,
        uint32 bitarraySize,
        address erc721ContractAddress,
        uint256[] calldata tokenIDs
    ) public {
        require(tokenIDs.length > 0, "Trying to create an empty envelope!");

        MerkleEnvelopeERC721 storage envelope = idToEnvelopes[envelopeID];
        envelope.creator = msg.sender;
        envelope.unclaimedPasswords = hashedMerkelRoot;
        envelope.isPasswordClaimed = new uint8[](bitarraySize/8 + 1);
        envelope.tokenAddress = erc721ContractAddress;
        envelope.tokenIDs = tokenIDs;

        for (uint8 tokenIdx = 0; tokenIdx < tokenIDs.length; tokenIdx++) {
            IERC721(erc721ContractAddress).transferFrom(
                msg.sender,
                address(this),
                tokenIDs[tokenIdx]
            );
        }
    }

    function openEnvelope(
        address receiver,
        string calldata envelopeID,
        bytes32[] memory proof,
        bytes32 leaf
    ) public {
        require(idToEnvelopes[envelopeID].tokenIDs.length > 0, "Envelope cannot be empty");
        MerkleEnvelopeERC721 storage currentEnv = idToEnvelopes[envelopeID];

        // First check if the password has been claimed
        // check index of the bitset, then check the position in the bitset
        uint256 bitarrayLen = currentEnv.isPasswordClaimed.length;
        uint32 idx = uint32(uint256(leaf) % bitarrayLen);
        uint32 bitsetIdx = idx / 8;
        uint8 positionInBitset = uint8(idx % 8);
        uint8 curBitSet = currentEnv.isPasswordClaimed[bitsetIdx];
        require(curBitSet.bit(positionInBitset) == 0, "password already used!");

        // Now check if it is a valid password
        bool isUnclaimed = MerkleProof.verify(proof, currentEnv.unclaimedPasswords, leaf);
        require(isUnclaimed, "password need to be valid!");

        // FXIME pick a random id in the array instead of just the first
        uint32 randIdx = random(uint32(currentEnv.tokenIDs.length));
        IERC721(currentEnv.tokenAddress).transferFrom(
            address(this),
            receiver,
            currentEnv.tokenIDs[randIdx]
        );
        _burn(currentEnv.tokenIDs, randIdx);
        
        // claim the password
        currentEnv.isPasswordClaimed[bitsetIdx].setBit(positionInBitset);
    }
}