// SPDX-License-Identifier: GPL-3.0
// vim: noai:ts=4:sw=4

pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './VickreyAuction.sol';

///@dev This implementation originally described the following scenario,
///     for demonstration purposes:
//
///          `_jobPoster` --> `workerNode`
///          `_jobPoster` <-- `workerNode`
//
///      It now has some notion of validator / `reviewerNodes`.

///////////////////////////////////////////////////////////////////////////////
// Notes for elsewhere

/*
    Early stopping    - Vickrey Auction, using the SimpleAuction contract?
    Active monitoring - Micropayment channel?
*/

/* 
    `rewardSchedule` is currently thought to be either a:
    - Continuous Reward (TBA: worker is rewarded essentially for descending the gradient)
    - Variable Reward (Early Stopping; kind-of a Boolean pay-off structure: as workers will
        only be rewarded if they have reached a threshold-level of accuracy)
    - Fixed Interval Reward (Active Monitoring)
    - Fixed Ratio Reward (for validators(?); as they will verify a certain number of models
        over a period of time: even if the selection process for them is pseudo-random?)
    ...encoded as a `string` or a series of `bytes`
*/

/* 
    Implement a form of a reputation score that basically updates how off 
    a given `endUser`'s estimation is of their workload's training time 
*/
///////////////////////////////////////////////////////////////////////////////

contract JobFactory {

    event JobDescriptionPosted(
        address jobPoster,
        uint16 estimatedTrainingTime,
        uint32 trainingDatasetSize,
        address auctionAddress,
        uint id,
        uint workerReward,
        uint biddingDeadline,
        uint revealDeadline,
        uint64 clientVersion
    );

    event UntrainedModelAndTrainingDatasetShared(
        address indexed jobPoster,
        uint64 targetErrorRate,
        address indexed workerNode,
        uint indexed id,
        string untrainedModelMagnetLink,
        string trainingDatasetMagnetLink
    );

    event TrainedModelShared(
        address indexed jobPoster,
        uint64 trainingErrorRate,
        address indexed workerNode,
        uint indexed id,
        string trainedModelMagnetLink
    );

    event TestingDatasetShared(
        address indexed jobPoster,
        uint64 targetErrorRate,
        uint indexed id,
        string trainedModelMagnetLink,
        string testingDatasetMagnetLink
    );

    event JobApproved(
        address indexed jobPoster,
        address indexed workerNode,
        address indexed validatorNode,
        string trainedModelMagnetLink,
        uint id
    );

    enum Status {
        PostedJobDescription,
        SharedUntrainedModelAndTrainingDataset,
        SharedTrainedModel,
        SharedTestingDataset,
        ApprovedJob
    }
    
    struct Job {
        uint auctionId;
        address workerNode;
        uint64 targetErrorRate;
        Status status;
        uint64  clientVersion;
    }

    // Client -> Job(s)
    // FIXME: auctionId is per-EVM basis - this is single-threading assumption
    mapping (address => Job[]) public jobs;

    IERC20 public token;

    VickreyAuction vickreyAuction;

    constructor(
        IERC20 _token,
        address auctionAddress
    ) {
        token = _token;
        vickreyAuction = VickreyAuction(auctionAddress);
    }

    /// @dev This is being called by `_jobPoster`
    //
    /// @notice `address(0)` is being passed to `Job` as a placeholder
    function postJobDescription(
        uint16 _estimatedTrainingTime,
        uint32 _trainingDatasetSize,
        uint64 _targetErrorRate,
        uint _minimumPayout,
        uint _workerReward,
        uint64 _clientVersion
    ) public {
        uint jobId = jobs[msg.sender].length;
        uint biddingDeadline = block.timestamp + 120;
        uint revealDeadline = block.timestamp + 240;
        vickreyAuction.start(
            _minimumPayout,
            biddingDeadline,
            revealDeadline,
            _workerReward,
            msg.sender);
        jobs[msg.sender].push(Job(
            jobId,
            address(0),
            _targetErrorRate,
            Status.PostedJobDescription,
            _clientVersion));
        emit JobDescriptionPosted(
            msg.sender,
            _estimatedTrainingTime,
            _trainingDatasetSize,
            address(vickreyAuction),
            jobId,
            _workerReward,
            biddingDeadline,
            revealDeadline,
            _clientVersion
        );
    }

    /// @dev This is being called by `_jobPoster`
    //
    /// @notice The untrained model and the training dataset have been encrypted
    ///         with the `workerNode` public key and `_jobPoster` private key
    function shareUntrainedModelAndTrainingDataset(
        uint _id,
        string memory _untrainedModelMagnetLink,
        string memory _trainingDatasetMagnetLink
    ) public {
        // FIXME require(vickreyAuction.ended(),'Auction has not ended');
        // Add check that auction has ended
        Job memory job = jobs[msg.sender][_id];
        require(job.status == Status.PostedJobDescription,'Job has not been posted');
        job.status = Status.SharedUntrainedModelAndTrainingDataset;
        (,,,,,,,address workerNode,) = vickreyAuction.auctions(msg.sender,_id);
        job.workerNode = workerNode;
        jobs[msg.sender][_id] = job;
        emit UntrainedModelAndTrainingDatasetShared(
            msg.sender,
            job.targetErrorRate,
            workerNode,
            _id,
            _untrainedModelMagnetLink,
            _trainingDatasetMagnetLink
        );
    }

    /// @dev This is being called by `workerNode`
    //
    /// TODO @notice The trained model has been encrypted with the `_jobPoster`s
    ///         public key and `workerNode` private key
    function shareTrainedModel(
        address _jobPoster,
        uint _id,
        string memory _trainedModelMagnetLink,
        uint64 _trainingErrorRate
    ) public {
        Job memory job = jobs[_jobPoster][_id];
        require(msg.sender == job.workerNode,'msg.sender must equal workerNode');
        require(job.status == Status.SharedUntrainedModelAndTrainingDataset,'Untrained model and training dataset has not been shared');
        require(job.targetErrorRate >= _trainingErrorRate,'targetErrorRate must be greater or equal to _trainingErrorRate');
        jobs[_jobPoster][_id].status = Status.SharedTrainedModel;
        emit TrainedModelShared(
            _jobPoster,
            _trainingErrorRate,
            msg.sender,
            _id,
            _trainedModelMagnetLink
        );
    }

    /// @dev This is being called by `_jobPoster`
    //
    /// TODO Have `../daemon` look-up the `trainedModelMagnetLink`
    ///      in the logs instead of re-parameterizing it, below.
    function shareTestingDataset(
        uint _id,
        string memory _trainedModelMagnetLink,
        string memory _testingDatasetMagnetLink
    ) public {
        Job memory job = jobs[msg.sender][_id];
        require(job.status == Status.SharedTrainedModel,'Trained model has not been shared');
        jobs[msg.sender][_id].status = Status.SharedTestingDataset;
        emit TestingDatasetShared(
            msg.sender,
            job.targetErrorRate,
            _id,
            _trainedModelMagnetLink,
            _testingDatasetMagnetLink
        );
    }

    /// @dev This is being called by a validator node
    function approveJob(
        address _jobPoster,
        uint _id,
        string memory _trainedModelMagnetLink
    ) public {
        Job memory job = jobs[_jobPoster][_id];
        require(msg.sender != job.workerNode,'msg.sender cannot equal workerNode');
        require(job.status == Status.SharedTestingDataset,'Testing dataset has not been shared');
        jobs[_jobPoster][_id].status = Status.ApprovedJob;
        // TODO Possible cruft below
        // FIXME
        // figure out if we want payout to be done here or in the daemon
        //vickreyAuction.payout(_jobPoster,_id);
        emit JobApproved(
            _jobPoster,
            job.workerNode,
            msg.sender,
            _trainedModelMagnetLink,
            _id            
        );
    }
}