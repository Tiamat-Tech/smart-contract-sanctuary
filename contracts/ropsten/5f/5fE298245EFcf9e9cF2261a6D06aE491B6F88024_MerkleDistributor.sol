//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
  Ref: https://github.com/Uniswap/merkle-distributor
 */
contract MerkleDistributor {
    bytes32 public immutable merkleRoot;
    address public tokenAddress;
    ERC20 public token;
    address private DIARewards;

    event Claimed(address account, uint256 amount);

    constructor(bytes32 _merkleRoot, address _tokenAddress, address _DIARewards) {
        merkleRoot = _merkleRoot;
        tokenAddress = _tokenAddress;
        token = ERC20(_tokenAddress);
        DIARewards = _DIARewards;
    }

    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) public {
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account, amount));

        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "MerkleDistributor: Invalid proof."
        );
        
        //transfer tokens from DIARewards to the account
        token.transferFrom(DIARewards, account, amount);

        emit Claimed(account, amount);
    }
}