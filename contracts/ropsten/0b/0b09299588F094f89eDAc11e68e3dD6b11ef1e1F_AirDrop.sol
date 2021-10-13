// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface IVestable {
    function vest(address _receiver, uint256 _amount) external;
}

contract AirDrop is Ownable {
    struct DropInfo {
        bytes32 root;
        uint256 total;
        uint256 remaining;
        bool active;
    }

    mapping(uint256 => DropInfo) drops;
    uint256 tranches;

    mapping(uint256 => mapping(address => bool)) private claimed;
    IVestable public vesting;

    event LogNewDrop(uint256 merkleIndex, bytes32 merkleRoot, uint256 totalAmount);
    event LogClaim(address indexed account, uint256 merkleIndex, uint256 amount);

    function setVesting(address _vesting) public onlyOwner {
        vesting = IVestable(_vesting);
    }

    function newDrop(bytes32 merkleRoot, uint256 totalAmount) external onlyOwner returns (uint256 trancheId) {
        trancheId = tranches;
        DropInfo memory di = DropInfo(merkleRoot, totalAmount, totalAmount, true);
        drops[trancheId] = di;
        tranches += 1;

        emit LogNewDrop(trancheId, merkleRoot, totalAmount);
    }

    function expireDrop(uint256 trancheId) external onlyOwner {
        require(trancheId < tranches, "AirDrop: !trancheId");
        drops[trancheId].active = false;
    }

    function isClaimed(uint256 trancheId, address account) public view returns (bool) {
        return claimed[trancheId][account];
    }

    function claim(
        uint256 trancheId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(trancheId < tranches, "AirDrop: !trancheId");
        require(!isClaimed(trancheId, msg.sender), "AirDrop: Drop already claimed");
        DropInfo storage di = drops[trancheId];
        require(di.active, "AirDrop: Drop expired");
        uint256 remaining = di.remaining;
        require(amount <= remaining, "AirDrop: No enough remaining");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(merkleProof, di.root, node), "AirDrop: Invalid proof");

        // Mark it claimed and send the token.
        claimed[trancheId][msg.sender] = true;
        di.remaining = remaining - amount;
        vesting.vest(msg.sender, amount);

        emit LogClaim(msg.sender, trancheId, amount);
    }

    function verifyDrop(
        uint256 trancheId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        require(trancheId < tranches, "AirDrop: !trancheId");
        require(!isClaimed(trancheId, msg.sender), "AirDrop: Drop already claimed");
        DropInfo storage di = drops[trancheId];
        require(di.active, "AirDrop: Drop expired");
        require(amount <= di.remaining, "AirDrop: No enough remaining");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        return MerkleProof.verify(merkleProof, di.root, node);
    }
}