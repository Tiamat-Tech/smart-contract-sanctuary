// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "hardhat/console.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IReflectERC20.sol";

contract ConsensusBased {
    /// @dev votes for/against the pending consensus
    int16 voteTotalForPendingConsensus;

    /// @dev proposed new threshold for consensus
    uint8 pendingConsensusThreshold;

    /// @dev current consensus threshold
    uint8 consensusThreshold;

    mapping(address => int) consensusVotes;
    address[] consensusVoters;

    event ConsensusVote(uint newThreshold, address voter, int vote, int weight);
    event ConsensusChanged(uint consensus, uint prev_consensus, int votes);

    /// @notice check if _votes exceeds the current threshold
    function reachedConsensus(uint8 _votes) view public returns (bool) {
        return _votes >= consensusThreshold;
    }
}

contract TokenGateway {
    IReflectERC20 public token;
    bool tokenSet;
}

contract GatewayValidators is ConsensusBased, TokenGateway {
    mapping(address => uint8) pendingValidators;
    mapping(address => bool) public validators;
    uint8 public totalValidators;

    mapping(address => uint16) validationFeeShare;
    uint256 validationFeeTotalShares;

    event ValidatorRegistered(address validator);
    event ValidatorDeregistered(address validator);

    modifier onlyValidator() {
        require(validators[msg.sender], "Validators only");
        _;
    }

    function registerValidator(address _v) public onlyValidator {
        // TODO Add ethToken requirement check?
        // require(ethToken.balanceOf(_v) > 1000e9, "Insufficient balance");
        require(!validators[_v], "Validator already exists");

        pendingValidators[_v] += 1;

        if (reachedConsensus(pendingValidators[_v])) {
            validators[_v] = true;
            totalValidators += 1;

            delete pendingValidators[_v];

            emit ValidatorRegistered(_v);
        }
    }

    function deregisterValidator(address _v) public onlyValidator {
        require(validators[_v], "Address must be a validator");
        require(totalValidators > 1, "Minimum of 2 validators required.");

        // TODO finish implementation by reaching consensus
        delete validators[_v];
        totalValidators -= 1;
        emit ValidatorDeregistered(_v);
    }

    function isValidator(address _v) view public returns (bool) {
        return validators[_v];
    }


    function setToken(address _tokenAddr) public onlyValidator {
        // TODO allow changing via consensus?
        require(!tokenSet, "Token already registered.");

        token = IReflectERC20(_tokenAddr);
        tokenSet = true;
    }

    /**
       @dev Allow validators to change the consensus once enough votes are reached.
    */
    function changeConsensus(uint8 _c, int8 _vote) public onlyValidator {
        require(_c <= totalValidators, "consensus exceeds validators");
        require(pendingConsensusThreshold == _c || pendingConsensusThreshold == 0, "You must vote for proposed threshold.");
        require(_vote == -1 || _vote == 1, "Vote must be -1 or 1");
        require(consensusVotes[msg.sender] != _vote, "duplicate vote");
        int16 voteWeight = 1;
        // Changing existing vote
        if (consensusVotes[msg.sender] == -1) {
            voteWeight = 2;
        }

        consensusVotes[msg.sender] = _vote;
        consensusVoters.push(msg.sender);

        pendingConsensusThreshold = _c;

        emit ConsensusVote(_c, msg.sender, _vote, voteWeight);

        if (_vote > 0) {
            voteTotalForPendingConsensus = voteTotalForPendingConsensus + (1 * voteWeight);
        } else {
            voteTotalForPendingConsensus = voteTotalForPendingConsensus - (1 * voteWeight);
        }

        if (reachedConsensus(uint8(voteTotalForPendingConsensus))) {

            if (voteTotalForPendingConsensus > 0) {
                emit ConsensusChanged(_c, consensusThreshold, voteTotalForPendingConsensus);
                consensusThreshold = _c;
            }

            // Reset consensus votes
            pendingConsensusThreshold = 0;

            voteTotalForPendingConsensus = 0;

            for (uint8 i=0;i < consensusVoters.length; i++) {
                delete consensusVotes[consensusVoters[i]];
            }

            delete consensusVoters;
        }
    }

    function consensusVoteState() view public returns (uint, int, uint) {
        return (pendingConsensusThreshold, voteTotalForPendingConsensus, totalValidators);
    }

    function viewConsensusThreshold() view public returns (uint) {
        return consensusThreshold;
    }
}

contract Gateway is GatewayValidators {
    using SafeMath for uint256;

    uint256 public lockedTokens;

    bool feesDeductedPreGateway;

    /// @dev gateways this one is sending too that should deduct fees this side
    mapping(address => bool) deductFeesOnTransferIn;

    /// @dev gateways that sent to this one that should deduct fees this side
    mapping(address => bool) deductFeesOnWithdraw;

    /// @dev hash of address + blockNum => amount awaiting votes
    mapping(bytes32 => uint) pendingOut;

    /// @dev hash of address + blockNum => uint = number of votes
    mapping(bytes32 => uint8) pendingOutVotes;

    /// @dev hash of (address + blockNum) + validator => voted
    mapping(bytes32 => bool) pendingOutVoted;

    /// @dev keep hash of address + blockNum => accepted to prevent new validators rerunning old transactions
    mapping(bytes32 => bool) pendingOutApproved;

    /// @dev address => amount approved for withdrawal
    mapping(address => uint256) approvedOut;



    event TransferNativeIn(address gw, address recipient, uint256 bNo , uint amount);
    event TransferNativeOut(address recipient, uint amount, bytes32 validatorHash);

    event Withdrawn(address to, uint amount);

    constructor() {
        validators[msg.sender] = true;
        totalValidators = 1;
        consensusThreshold = 1;
    }

    /**
    * @dev gateways added here have already applied the fees their side
    */
    function deductFeesOnTransferInToGateway(address gw, bool v) public onlyValidator {
        deductFeesOnTransferIn[gw] = v;
    }

    /**
    * @dev gateways added here need the fees to be distributed this side
    */
    function deductFeesOnWithdrawFromGateway(address gw, bool v) public onlyValidator {
        deductFeesOnWithdraw[gw] = v;
    }

    /**
    *    @dev call after approving the gateway allowance on the ethToken contract.
    */
    function transferNativeIn(address targetGw, address to, uint256 amount) virtual public {
        if (deductFeesOnTransferIn[targetGw]) {
            require(token.transferFromForceFees(msg.sender, address(this), amount), "Failed to transfer in");
        } else {
            require(token.transferFrom(msg.sender, address(this), amount), "Failed to transfer in");
        }

        uint256 finalAmount;

        // @dev we can't add the gateway to the original ETH token so we handle fees here
        if (deductFeesOnTransferIn[targetGw]) {
            uint256 fee = amount.mul(5).div(100);
            finalAmount = amount.sub(fee);
        } else {
            finalAmount = amount;
        }

        lockedTokens = lockedTokens.add(finalAmount);

        emit TransferNativeIn(targetGw, to, block.number, finalAmount);
    }

    /**
     @dev called by validators who received the TransferNativeIn event from the other gateway.
    */
    function transferNativeOut(address sendingGw, address to, uint blockNum, uint amount) public onlyValidator {
        require(lockedTokens >= amount, "Insufficient liquidity");

        bytes32 hash = keccak256(abi.encodePacked(to, blockNum));
        require(!pendingOutApproved[hash], "Already approved");
        require(pendingOut[hash] == amount || pendingOut[hash] == 0, "Outgoing transaction amount incorrect.");

        bytes32 validatorHash = keccak256(abi.encodePacked(hash, msg.sender));
        require(!pendingOutVoted[validatorHash], "Duplicate vote");

        pendingOut[hash] = amount;
        pendingOutVotes[hash] += 1;
        pendingOutVoted[validatorHash] = true;

        validationFeeShare[msg.sender] += 1;
        validationFeeTotalShares += 1;

        if (reachedConsensus(pendingOutVotes[hash])) {
            lockedTokens = lockedTokens.sub(amount);

            if (deductFeesOnWithdraw[sendingGw]) {
                token.distributeOnlyFees(amount);

                uint256 fee = amount.mul(5).div(100);
                amount = amount.sub(fee);
            }

            approvedOut[to] = approvedOut[to].add(amount);
            pendingOutApproved[hash] = true;

            emit TransferNativeOut(to, pendingOut[hash], validatorHash);

            delete pendingOut[hash];
            delete pendingOutVotes[hash];
        }
    }

    /**
     @notice Check the number of approvals for an incoming transfer
     @return Number of votes received
    */
    function pendingWithdrawVotes(bytes32 hash) view public returns (uint) {
        return pendingOutVotes[hash];
    }

    /**
    @notice verify if validator has voted on transaction already
    */
    function validatorVoted(bytes32 hash) view public returns (bool) {
        return pendingOutVoted[hash];
    }

    function withdraw() public {
        require(approvedOut[msg.sender] > 0);
        uint256 amount = approvedOut[msg.sender];

        approvedOut[msg.sender] = 0;

        token.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function allowance(address a) view public returns (uint256){
        return approvedOut[a];
    }

    function unclaimedTotalFees() view public returns (uint256) {
        uint256 balance = token.balanceOf(address(this));

        return balance.sub(lockedTokens);
    }

    //    function validatorAllowance() view public onlyValidator returns (uint256) {
    //        uint256 fees = unclaimedTotalFees();
    //
    //        uint256 allowance = 0;
    //
    //        return allowance;
    //    }

    /**
     @dev allow validators to withdraw their share of fees
    */
    function withdrawFees() public onlyValidator {
        // Get unclaimedTotalFees
        // Calculate share based on validationFeeShare
        // Reset share and transfer tokens out to validator
    }

    receive() payable external {

    }
}