//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CommitRevealBase {
    uint256 public commitDeadline;
    uint256 public revealDeadline;
    bytes32 private randomSeed;
    mapping(address => bytes32) public sealedRandomShards;

    function getRandomSeed() internal view returns (bytes32) {
        require(
            block.timestamp > revealDeadline,
            "Random Seed not finalized yet"
        );
        return randomSeed;
    }

    function commit(bytes32 _sealedRandomShard) internal {
        require(block.timestamp < commitDeadline, "Commit phase closed.");
        sealedRandomShards[msg.sender] = _sealedRandomShard;
    }

    function reveal(uint256 _randomShard) public {
        require(block.timestamp >= commitDeadline, "Still in commit phase.");
        require(block.timestamp < revealDeadline, "Reveal phase closed.");

        bytes32 sealedRandomShard = seal(_randomShard);
        require(
            sealedRandomShard == sealedRandomShards[msg.sender],
            "Invalid Random Shard provided!"
        );

        randomSeed = keccak256(abi.encode(randomSeed, _randomShard));
    }

    // Helper view function to seal a given _randomShard
    function seal(uint256 _randomShard) public view returns (bytes32) {
        return keccak256(abi.encode(msg.sender, _randomShard));
    }
}