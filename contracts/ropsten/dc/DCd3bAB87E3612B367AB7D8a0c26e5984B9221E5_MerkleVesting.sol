// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "./Vesting.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleVesting is Ownable, TokenVesting {
    using SafeERC20 for IERC20;

    event Claim(
        address indexed beneficiary,
        uint indexed duration,
        uint indexed amount,
        uint instantReleaseAmount,
        uint residualAmount
    );

    bytes32 public merkleRoot;
    uint public vestingStartTimestamp;
    mapping(bytes32 => bool) claimed;

    constructor(address token_, bytes32 merkleRoot_) TokenVesting(token_) {
        merkleRoot = merkleRoot_;
    }

    function claim(
        address beneficiary,
        uint duration,
        uint amount,
        uint instantReleaseBasis,
        bytes32[] calldata merkleProof
    ) external {
        require(_msgSender() == beneficiary, "Claim from wrong address");

        uint timestamp = vestingStartTimestamp;

        require(0 != timestamp, "Start time not set");
        require(block.timestamp >= timestamp, "Too early");

        bytes32 node = keccak256(abi.encodePacked(beneficiary, duration, amount, instantReleaseBasis));

        require(!claimed[node], "Already claimed");

        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Invalid proof");

        claimed[node] = true;

        uint instantReleaseAmount = (amount * instantReleaseBasis) / 10_000;
        uint residualAmount = amount - instantReleaseAmount;

        _token.safeTransfer(beneficiary, residualAmount);

        createVestingSchedule(beneficiary, timestamp, 0, duration, 1, false, residualAmount);

        emit Claim(beneficiary, duration, amount, instantReleaseAmount, residualAmount);
    }

    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
    }

    function updateVestingStart(uint newTimestamp) external onlyOwner {
        require(0 == vestingStartTimestamp, "Vesting start timestamp already set");

        vestingStartTimestamp = newTimestamp;
    }
}