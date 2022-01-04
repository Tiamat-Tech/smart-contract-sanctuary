//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClaimNAFF is Ownable {
    bytes32 private merkleRoot;

    mapping(address => bool) private isClaimedList;

    event Claimed(address account, uint256 amount);

    constructor(bytes32 _merkleRoot) {
        merkleRoot = _merkleRoot;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function isClaimed(address account) public view returns (bool) {
        return isClaimedList[account];
    }

    function claim(
        address account,
        uint256 amount,
        address token,
        bytes32[] calldata merkleProof
    ) public {
        // Basic checking
        require(!isClaimedList[msg.sender], "ERROR: Tokens Already Claimed.");

        bytes32 nodeData = keccak256(abi.encodePacked(account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, nodeData), "ERROR: Invalid Proof.");

        require(amount <= IERC20(token).balanceOf(address(this)), "ERROR: Not Enough Token");

        // Mark this record and transfer tokens
        isClaimedList[msg.sender] = true;
        require(IERC20(token).transfer(account, amount), "ERROR: Transfer Failed.");

        emit Claimed(account, amount);
    }
}