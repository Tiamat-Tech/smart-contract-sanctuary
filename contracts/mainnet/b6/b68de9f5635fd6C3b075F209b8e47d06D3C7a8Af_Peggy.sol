// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "./math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Peggy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // These are updated often
    bytes32 public state_lastValsetCheckpoint;
    mapping(address => uint256) public state_lastBatchNonces;
    uint256 public state_lastValsetNonce = 0;
    uint256 public state_lastEventNonce = 0;

    // These are set once at initialization
    bytes32 public state_peggyId;
    uint256 public state_powerThreshold;

    // TransactionBatchExecutedEvent and SendToCosmosEvent both include the field _eventNonce.
    // This is incremented every time one of these events is emitted. It is checked by the
    // Cosmos module to ensure that all events are received in order, and that none are lost.
    //
    // ValsetUpdatedEvent does not include the field _eventNonce because it is never submitted to the Cosmos
    // module. It is purely for the use of relayers to allow them to successfully submit batches.
    event TransactionBatchExecutedEvent(uint256 indexed _batchNonce, address indexed _token, uint256 _eventNonce);
    event SendToCosmosEvent(
        address indexed _tokenContract,
        address indexed _sender,
        address indexed _destination,
        uint256 _amount,
        uint256 _eventNonce,
        string _name,
        string _symbol,
        uint8 _decimals
    );
    event ValsetUpdatedEvent(uint256 indexed _newValsetNonce, address[] _validators, uint256[] _powers);

    // TEST FIXTURES
    // These are here to make it easier to measure gas usage. They should be removed before production
    function testMakeCheckpoint(
        address[] memory _validators,
        uint256[] memory _powers,
        uint256 _valsetNonce,
        bytes32 _peggyId
    ) public pure {
        makeCheckpoint(_validators, _powers, _valsetNonce, _peggyId);
    }

    function testCheckValidatorSignatures(
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        bytes32 _theHash,
        uint256 _powerThreshold
    ) public pure {
        checkValidatorSignatures(_currentValidators, _currentPowers, _v, _r, _s, _theHash, _powerThreshold);
    }

    // END TEST FIXTURES

    function lastBatchNonce(address _erc20Address) public view returns (uint256) {
        return state_lastBatchNonces[_erc20Address];
    }

    // Utility function to verify geth style signatures
    function verifySig(
        address _signer,
        bytes32 _theHash,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) private pure returns (bool) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _theHash));
        return _signer == ecrecover(messageDigest, _v, _r, _s);
    }

    // Make a new checkpoint from the supplied validator set
    // A checkpoint is a hash of all relevant information about the valset. This is stored by the contract,
    // instead of storing the information directly. This saves on storage and gas.
    // The format of the checkpoint is:
    // h(peggyId, "checkpoint", valsetNonce, validators[], powers[])
    // Where h is the keccak256 hash function.
    // The validator powers must be decreasing or equal. This is important for checking the signatures on the
    // next valset, since it allows the caller to stop verifying signatures once a quorum of signatures have been verified.
    function makeCheckpoint(
        address[] memory _validators,
        uint256[] memory _powers,
        uint256 _valsetNonce,
        bytes32 _peggyId
    ) private pure returns (bytes32) {
        // bytes32 encoding of the string "checkpoint"
        bytes32 methodName = 0x636865636b706f696e7400000000000000000000000000000000000000000000;

        bytes32 checkpoint = keccak256(abi.encode(_peggyId, methodName, _valsetNonce, _validators, _powers));

        return checkpoint;
    }

    function checkValidatorSignatures(
        // The current validator set and their powers
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        // The current validator's signatures
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        // This is what we are checking they have signed
        bytes32 _theHash,
        uint256 _powerThreshold
    ) private pure {
        uint256 cumulativePower = 0;

        for (uint256 i = 0; i < _currentValidators.length; i++) {
            // If v is set to 0, this signifies that it was not possible to get a signature from this validator and we skip evaluation
            // (In a valid signature, it is either 27 or 28)
            if (_v[i] != 0) {
                // Check that the current validator has signed off on the hash
                require(verifySig(_currentValidators[i], _theHash, _v[i], _r[i], _s[i]), "Validator signature does not match.");

                // Sum up cumulative power
                cumulativePower = cumulativePower + _currentPowers[i];

                // Break early to avoid wasting gas
                if (cumulativePower > _powerThreshold) {
                    break;
                }
            }
        }

        // Check that there was enough power
        require(cumulativePower > _powerThreshold, "Submitted validator set signatures do not have enough power.");
        // Success
    }

    // This updates the valset by checking that the validators in the current valset have signed off on the
    // new valset. The signatures supplied are the signatures of the current valset over the checkpoint hash
    // generated from the new valset.
    // Anyone can call this function, but they must supply valid signatures of state_powerThreshold of the current valset over
    // the new valset.
    function updateValset(
        // The new version of the validator set
        address[] memory _newValidators,
        uint256[] memory _newPowers,
        uint256 _newValsetNonce,
        // The current validators that approve the change
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        uint256 _currentValsetNonce,
        // These are arrays of the parts of the current validator's signatures
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s
    ) public {
        // CHECKS

        // Check that the valset nonce is greater than the old one
        require(_newValsetNonce > _currentValsetNonce, "New valset nonce must be greater than the current nonce");

        // Check that new validators and powers set is well-formed
        require(_newValidators.length == _newPowers.length, "Malformed new validator set");

        // Check that current validators, powers, and signatures (v,r,s) set is well-formed
        require(
            _currentValidators.length == _currentPowers.length &&
                _currentValidators.length == _v.length &&
                _currentValidators.length == _r.length &&
                _currentValidators.length == _s.length,
            "Malformed current validator set"
        );

        // Check that the supplied current validator set matches the saved checkpoint
        require(
            makeCheckpoint(_currentValidators, _currentPowers, _currentValsetNonce, state_peggyId) == state_lastValsetCheckpoint,
            "Supplied current validators and powers do not match checkpoint."
        );

        // Check that enough current validators have signed off on the new validator set
        bytes32 newCheckpoint = makeCheckpoint(_newValidators, _newPowers, _newValsetNonce, state_peggyId);

        checkValidatorSignatures(_currentValidators, _currentPowers, _v, _r, _s, newCheckpoint, state_powerThreshold);

        // ACTIONS

        // Stored to be used next time to validate that the valset
        // supplied by the caller is correct.
        state_lastValsetCheckpoint = newCheckpoint;

        // Store new nonce
        state_lastValsetNonce = _newValsetNonce;

        // LOGS

        emit ValsetUpdatedEvent(_newValsetNonce, _newValidators, _newPowers);
    }

    // submitBatch processes a batch of Cosmos -> Ethereum transactions by sending the tokens in the transactions
    // to the destination addresses. It is approved by the current Cosmos validator set.
    // Anyone can call this function, but they must supply valid signatures of state_powerThreshold of the current valset over
    // the batch.
    function submitBatch(
        // The validators that approve the batch
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        uint256 _currentValsetNonce,
        // These are arrays of the parts of the validators signatures
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        // The batch of transactions
        uint256[] memory _amounts,
        address[] memory _destinations,
        uint256[] memory _fees,
        uint256 _batchNonce,
        address _tokenContract
    ) public {
        // CHECKS scoped to reduce stack depth
        {
            // Check that the batch nonce is higher than the last nonce for this token
            require(state_lastBatchNonces[_tokenContract] < _batchNonce, "New batch nonce must be greater than the current nonce");

            // Check that current validators, powers, and signatures (v,r,s) set is well-formed
            require(
                _currentValidators.length == _currentPowers.length &&
                    _currentValidators.length == _v.length &&
                    _currentValidators.length == _r.length &&
                    _currentValidators.length == _s.length,
                "Malformed current validator set"
            );

            // Check that the supplied current validator set matches the saved checkpoint
            require(
                makeCheckpoint(_currentValidators, _currentPowers, _currentValsetNonce, state_peggyId) == state_lastValsetCheckpoint,
                "Supplied current validators and powers do not match checkpoint."
            );

            // Check that the transaction batch is well-formed
            require(_amounts.length == _destinations.length && _amounts.length == _fees.length, "Malformed batch of transactions");

            // Check that enough current validators have signed off on the transaction batch and valset
            checkValidatorSignatures(
                _currentValidators,
                _currentPowers,
                _v,
                _r,
                _s,
                // Get hash of the transaction batch and checkpoint
                keccak256(
                    abi.encode(
                        state_peggyId,
                        // bytes32 encoding of "transactionBatch"
                        0x7472616e73616374696f6e426174636800000000000000000000000000000000,
                        _amounts,
                        _destinations,
                        _fees,
                        _batchNonce,
                        _tokenContract
                    )
                ),
                state_powerThreshold
            );

            // ACTIONS

            // Store batch nonce
            state_lastBatchNonces[_tokenContract] = _batchNonce;

            {
                // Send transaction amounts to destinations
                uint256 totalFee;
                for (uint256 i = 0; i < _amounts.length; i++) {
                    IERC20(_tokenContract).safeTransfer(_destinations[i], _amounts[i]);
                    totalFee = totalFee.add(_fees[i]);
                }

                // Send transaction fees to msg.sender
                IERC20(_tokenContract).safeTransfer(msg.sender, totalFee);
            }
        }

        // LOGS scoped to reduce stack depth
        {
            state_lastEventNonce = state_lastEventNonce.add(1);
            emit TransactionBatchExecutedEvent(_batchNonce, _tokenContract, state_lastEventNonce);
        }
    }

    mapping(address => bool) public seenTokens;
    mapping(address => string) public tokenSymbols;
    mapping(address => string) public tokenNames;
    mapping(address => uint8) public tokenDecimals;

    function sendToCosmos(
        address _tokenContract,
        address _destination,
        uint256 _amount
    ) public {
        IERC20(_tokenContract).safeTransferFrom(msg.sender, address(this), _amount);

        // store values if first time
        if (!seenTokens[_tokenContract]) {
            seenTokens[_tokenContract] = true;
            tokenNames[_tokenContract] = ERC20(_tokenContract).name();
            tokenSymbols[_tokenContract] = ERC20(_tokenContract).symbol();
            tokenDecimals[_tokenContract] = ERC20(_tokenContract).decimals();
        }

        state_lastEventNonce = state_lastEventNonce.add(1);
        emit SendToCosmosEvent(
            _tokenContract,
            msg.sender,
            _destination,
            _amount,
            state_lastEventNonce,
            tokenNames[_tokenContract],
            tokenSymbols[_tokenContract],
            tokenDecimals[_tokenContract]
        );
    }

    constructor(
        // A unique identifier for this peggy instance to use in signatures
        bytes32 _peggyId,
        // How much voting power is needed to approve operations
        uint256 _powerThreshold,
        // The validator set
        address[] memory _validators,
        uint256[] memory _powers
    ) public {
        // CHECKS

        // Check that validators, powers, and signatures (v,r,s) set is well-formed
        require(_validators.length == _powers.length, "Malformed current validator set");

        // Check cumulative power to ensure the contract has sufficient power to actually
        // pass a vote
        uint256 cumulativePower = 0;
        for (uint256 i = 0; i < _powers.length; i++) {
            cumulativePower = cumulativePower + _powers[i];
            if (cumulativePower > _powerThreshold) {
                break;
            }
        }
        require(cumulativePower > _powerThreshold, "Submitted validator set signatures do not have enough power.");

        bytes32 newCheckpoint = makeCheckpoint(_validators, _powers, 0, _peggyId);

        // ACTIONS

        state_peggyId = _peggyId;
        state_powerThreshold = _powerThreshold;
        state_lastValsetCheckpoint = newCheckpoint;

        // LOGS

        emit ValsetUpdatedEvent(0, _validators, _powers);
    }
}