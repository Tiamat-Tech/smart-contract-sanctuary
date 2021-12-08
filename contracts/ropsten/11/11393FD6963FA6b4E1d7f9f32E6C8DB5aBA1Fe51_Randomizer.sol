//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICryptoBees.sol";
import "./Traits.sol";

contract Randomizer is Ownable {
    ICryptoBees beesContract;

    struct Commit {
        bytes32 commit;
        uint64 block;
        bool revealed;
    }

    mapping(address => Commit) public commits;
    mapping(address => bool) controllers;

    event MintRevealed(address indexed owner, uint256 tokenId, uint256 _type);
    event CommitHash(address indexed sender, bytes32 dataHash, uint64 block);
    event RevealHash(address indexed sender, bytes32 revealHash, uint256 random);

    constructor() {}

    function setContracts(address _BEES) external onlyOwner {
        beesContract = ICryptoBees(_BEES);
    }

    function revealToken(uint256 blockNum) external {
        require(controllers[_msgSender()] || _msgSender() == address(beesContract), "Only controllers can reveal");

        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        if (beesContract.getUnrevealed() < blockNum && beesContract.doesExist(unrevealedTokenIndex + 1)) {
            _revealOne(unrevealedTokenIndex + 1);
        }
    }

    function revealMany(uint256 n) external onlyOwner {
        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        for (uint256 i = unrevealedTokenIndex; i < unrevealedTokenIndex + n; i++) {
            if (beesContract.doesExist(i + 1)) {
                _revealOne(i + 1);
                beesContract.pushToUnrevealedToken(block.number);
            }
        }
    }

    function _revealOne(uint256 i) private {
        uint256 seed = random(i);
        uint256 num = ((seed & 0xFFFF) % 100);
        uint8 _type = 1;
        if (num == 0) _type = 3;
        else if (num < 10) _type = 2;
        beesContract.setTokenType(i, _type);
        beesContract.setUnrevealedIndex(i);
        emit MintRevealed(_msgSender(), i, _type);
    }

    function howManyUnrevealed() public view returns (uint256) {
        uint256 unrevealedTokenIndex = beesContract.getUnrevealedIndex();
        uint256 minted = beesContract.getMinted();
        return minted - unrevealedTokenIndex;
    }

    function random(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tx.origin, blockhash(block.number - 1), block.timestamp, seed)));
    }

    function commit(bytes32 dataHash) public {
        commits[msg.sender].commit = dataHash;
        commits[msg.sender].block = uint64(block.number);
        commits[msg.sender].revealed = false;
        emit CommitHash(msg.sender, commits[msg.sender].commit, commits[msg.sender].block);
    }

    function getHash(bytes32 data) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), data));
    }

    function commitRevealRandom(bytes32 revealHash) public returns (uint256) {
        require(commits[msg.sender].revealed == false, "Randomizer: Commit already revealed");
        commits[msg.sender].revealed = true;
        require(getHash(revealHash) == commits[msg.sender].commit, "Randomizer: Revealed hash does not match commit");
        require(uint64(block.number) > commits[msg.sender].block, "Randomizer: Reveal and commit happened on the same block");
        require(uint64(block.number) <= commits[msg.sender].block + 250, "Randomizer: Revealed too late");
        bytes32 blockHash = blockhash(commits[msg.sender].block);
        uint256 rnd = uint256(keccak256(abi.encodePacked(blockHash, blockhash(block.number - 1), revealHash))) % 100;
        emit RevealHash(msg.sender, revealHash, rnd);
        return rnd;
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}