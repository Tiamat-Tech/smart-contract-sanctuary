pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IVestable {
    function vest(address _receiver, uint256 _amount) external;
}

contract AirDrop is Ownable {
    bytes32[] public merkleRoots;
    bytes32 public pendingMerkleRoot;

    mapping(uint256 => mapping(uint256 => uint256)) private claimedBitMap;
    IVestable public vesting;

    event Claimed(uint256 merkleIndex, uint256 index, address account, uint256 amount);

    function setVesting(address _vesting) public onlyOwner {
        vesting = IVestable(_vesting);
    }

    function proposewMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        pendingMerkleRoot = _merkleRoot;
    }

    function reviewPendingMerkleRoot(bool _approved) public onlyOwner {
        require(pendingMerkleRoot != 0x00);
        if (_approved) {
            merkleRoots.push(pendingMerkleRoot);
        }
        delete pendingMerkleRoot;
    }

    function isClaimed(uint256 merkleIndex, uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[merkleIndex][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 merkleIndex, uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[merkleIndex][claimedWordIndex] =
            claimedBitMap[merkleIndex][claimedWordIndex] |
            (1 << claimedBitIndex);
    }

    function claim(
        uint256 merkleIndex,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(merkleIndex < merkleRoots.length, "MerkleDistributor: Invalid merkleIndex");
        require(!isClaimed(merkleIndex, index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
        require(verify(merkleProof, merkleRoots[merkleIndex], node), "MerkleDistributor: Invalid proof.");

        // Mark it claimed and send the token.
        _setClaimed(merkleIndex, index);
        vesting.vest(msg.sender, amount);

        emit Claimed(merkleIndex, index, msg.sender, amount);
    }

    function verifyDrop(
        uint256 merkleIndex,
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        require(merkleIndex < merkleRoots.length, "MerkleDistributor: Invalid merkleIndex");
        require(!isClaimed(merkleIndex, index), "MerkleDistributor: Drop already claimed.");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, msg.sender, amount));
        return verify(merkleProof, merkleRoots[merkleIndex], node);
    }

    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}