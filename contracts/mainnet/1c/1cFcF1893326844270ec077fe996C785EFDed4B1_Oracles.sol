// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./presets/OwnablePausableUpgradeable.sol";
import "./interfaces/IRewardEthToken.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IOracles.sol";
import "./interfaces/IMerkleDistributor.sol";
import "./interfaces/IPoolValidators.sol";
import "./interfaces/IOraclesV1.sol";

/**
 * @title Oracles
 *
 * @dev Oracles contract stores accounts responsible for submitting or update values based on the off-chain data.
 * The threshold of inputs from different oracles is required to submit the data.
 */
contract Oracles is IOracles, OwnablePausableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // @dev Rewards nonce is used to protect from submitting the same rewards vote several times.
    CountersUpgradeable.Counter private rewardsNonce;

    // @dev Validators nonce is used to protect from submitting the same validator vote several times.
    CountersUpgradeable.Counter private validatorsNonce;

    // @dev Address of the RewardEthToken contract.
    IRewardEthToken private rewardEthToken;

    // @dev Address of the Pool contract.
    IPool private pool;

    // @dev Address of the Pool contract.
    IPoolValidators private poolValidators;

    // @dev Address of the MerkleDistributor contract.
    IMerkleDistributor private merkleDistributor;

    /**
    * @dev Modifier for checking whether the caller is an oracle.
    */
    modifier onlyOracle() {
        require(hasRole(ORACLE_ROLE, msg.sender), "Oracles: access denied");
        _;
    }

    /**
     * @dev See {IOracles-initialize}.
     */
    function initialize(
        address admin,
        address oraclesV1,
        address _rewardEthToken,
        address _pool,
        address _poolValidators,
        address _merkleDistributor
    )
        external override initializer
    {
        require(admin != address(0), "Pool: invalid admin address");
        require(_rewardEthToken != address(0), "Pool: invalid RewardEthToken address");
        require(_pool != address(0), "Pool: invalid Pool address");
        require(_poolValidators != address(0), "Pool: invalid PoolValidators address");
        require(_merkleDistributor != address(0), "Pool: invalid MerkleDistributor address");

        __OwnablePausableUpgradeable_init(admin);

        // migrate data from previous Oracles contract
        rewardsNonce._value = IOraclesV1(oraclesV1).currentNonce().add(1000);
        uint256 oraclesCount = AccessControlUpgradeable(oraclesV1).getRoleMemberCount(ORACLE_ROLE);
        for(uint256 i = 0; i < oraclesCount; i++) {
            address oracle = AccessControlUpgradeable(oraclesV1).getRoleMember(ORACLE_ROLE, i);
            _setupRole(ORACLE_ROLE, oracle);
            emit OracleAdded(oracle);
        }

        rewardEthToken = IRewardEthToken(_rewardEthToken);
        pool = IPool(_pool);
        poolValidators = IPoolValidators(_poolValidators);
        merkleDistributor = IMerkleDistributor(_merkleDistributor);
        emit Initialized(rewardsNonce.current());
    }

    /**
     * @dev See {IOracles-currentRewardsNonce}.
     */
    function currentRewardsNonce() external override view returns (uint256) {
        return rewardsNonce.current();
    }

    /**
     * @dev See {IOracles-currentValidatorsNonce}.
     */
    function currentValidatorsNonce() external override view returns (uint256) {
        return validatorsNonce.current();
    }

    /**
     * @dev See {IOracles-isOracle}.
     */
    function isOracle(address account) external override view returns (bool) {
        return hasRole(ORACLE_ROLE, account);
    }

    /**
     * @dev See {IOracles-addOracle}.
     */
    function addOracle(address account) external override {
        grantRole(ORACLE_ROLE, account);
        emit OracleAdded(account);
    }

    /**
     * @dev See {IOracles-removeOracle}.
     */
    function removeOracle(address account) external override {
        revokeRole(ORACLE_ROLE, account);
        emit OracleRemoved(account);
    }

    /**
     * @dev See {IOracles-isMerkleRootVoting}.
     */
    function isMerkleRootVoting() public override view returns (bool) {
        uint256 lastRewardBlockNumber = rewardEthToken.lastUpdateBlockNumber();
        return merkleDistributor.lastUpdateBlockNumber() < lastRewardBlockNumber && lastRewardBlockNumber != block.number;
    }

    /**
    * @dev Function for checking whether number of signatures is enough to update the value.
    * @param signaturesCount - number of signatures.
    */
    function isEnoughSignatures(uint256 signaturesCount) internal view returns (bool) {
        return signaturesCount.mul(3) > getRoleMemberCount(ORACLE_ROLE).mul(2);
    }

    /**
     * @dev See {IOracles-submitRewards}.
     */
    function submitRewards(
        uint256 totalRewards,
        uint256 activatedValidators,
        bytes[] calldata signatures
    )
        external override onlyOracle whenNotPaused
    {
        require(isEnoughSignatures(signatures.length), "Oracles: invalid number of signatures");

        // calculate candidate ID hash
        uint256 nonce = rewardsNonce.current();
        bytes32 candidateId = ECDSAUpgradeable.toEthSignedMessageHash(
            keccak256(abi.encode(nonce, activatedValidators, totalRewards))
        );

        // check signatures and calculate number of submitted oracle votes
        address[] memory signedOracles = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            address signer = ECDSAUpgradeable.recover(candidateId, signature);
            require(hasRole(ORACLE_ROLE, signer), "Oracles: invalid signer");

            for (uint256 j = 0; j < i; j++) {
                require(signedOracles[j] != signer, "Oracles: repeated signature");
            }
            signedOracles[i] = signer;
            emit RewardsVoteSubmitted(msg.sender, signer, nonce, totalRewards, activatedValidators);
        }

        // increment nonce for future signatures
        rewardsNonce.increment();

        // update total rewards
        rewardEthToken.updateTotalRewards(totalRewards);

        // update activated validators
        if (activatedValidators != pool.activatedValidators()) {
            pool.setActivatedValidators(activatedValidators);
        }
    }

    /**
     * @dev See {IOracles-submitMerkleRoot}.
     */
    function submitMerkleRoot(
        bytes32 merkleRoot,
        string calldata merkleProofs,
        bytes[] calldata signatures
    )
        external override onlyOracle whenNotPaused
    {
        require(isMerkleRootVoting(), "Oracles: too early");
        require(isEnoughSignatures(signatures.length), "Oracles: invalid number of signatures");

        // calculate candidate ID hash
        uint256 nonce = rewardsNonce.current();
        bytes32 candidateId = ECDSAUpgradeable.toEthSignedMessageHash(
            keccak256(abi.encode(nonce, merkleProofs, merkleRoot))
        );

        // check signatures and calculate number of submitted oracle votes
        address[] memory signedOracles = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            address signer = ECDSAUpgradeable.recover(candidateId, signature);
            require(hasRole(ORACLE_ROLE, signer), "Oracles: invalid signer");

            for (uint256 j = 0; j < i; j++) {
                require(signedOracles[j] != signer, "Oracles: repeated signature");
            }
            signedOracles[i] = signer;
            emit MerkleRootVoteSubmitted(msg.sender, signer, nonce, merkleRoot, merkleProofs);
        }

        // increment nonce for future signatures
        rewardsNonce.increment();

        // update merkle root
        merkleDistributor.setMerkleRoot(merkleRoot, merkleProofs);
    }

    /**
     * @dev See {IOracles-initializeValidator}.
     */
    function initializeValidator(
        IPoolValidators.DepositData calldata depositData,
        bytes32[] calldata merkleProof,
        bytes[] calldata signatures
    )
        external override whenNotPaused
    {
        require(isEnoughSignatures(signatures.length), "Oracles: invalid number of signatures");

        // calculate candidate ID hash
        uint256 nonce = validatorsNonce.current();
        bytes32 candidateId = ECDSAUpgradeable.toEthSignedMessageHash(
            keccak256(abi.encode(nonce, depositData.publicKey, depositData.operator))
        );

        // check signatures and calculate number of submitted oracle votes
        address[] memory signedOracles = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            address signer = ECDSAUpgradeable.recover(candidateId, signature);
            require(hasRole(ORACLE_ROLE, signer), "Oracles: invalid signer");

            for (uint256 j = 0; j < i; j++) {
                require(signedOracles[j] != signer, "Oracles: repeated signature");
            }
            signedOracles[i] = signer;
            emit InitializeValidatorVoteSubmitted(msg.sender, signer, depositData.operator, depositData.publicKey, nonce);
        }

        // increment nonce for future signatures
        validatorsNonce.increment();

        // initialize validator
        poolValidators.initializeValidator(depositData, merkleProof);
    }

    /**
     * @dev See {IOracles-finalizeValidator}.
     */
    function finalizeValidator(
        IPoolValidators.DepositData calldata depositData,
        bytes32[] calldata merkleProof,
        bytes[] calldata signatures
    )
        external override whenNotPaused
    {
        require(isEnoughSignatures(signatures.length), "Oracles: invalid number of signatures");

        // calculate candidate ID hash
        uint256 nonce = validatorsNonce.current();
        bytes32 candidateId = ECDSAUpgradeable.toEthSignedMessageHash(
            keccak256(abi.encode(nonce, depositData.publicKey, depositData.operator))
        );

        // check signatures and calculate number of submitted oracle votes
        address[] memory signedOracles = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            address signer = ECDSAUpgradeable.recover(candidateId, signature);
            require(hasRole(ORACLE_ROLE, signer), "Oracles: invalid signer");

            for (uint256 j = 0; j < i; j++) {
                require(signedOracles[j] != signer, "Oracles: repeated signature");
            }
            signedOracles[i] = signer;
            emit FinalizeValidatorVoteSubmitted(msg.sender, signer, depositData.operator, depositData.publicKey, nonce);
        }

        // increment nonce for future signatures
        validatorsNonce.increment();

        // finalize validator
        poolValidators.finalizeValidator(depositData, merkleProof);
    }
}