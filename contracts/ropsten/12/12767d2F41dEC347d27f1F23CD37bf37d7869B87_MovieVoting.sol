//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./matic/BasicMetaTransaction.sol";
import "./interfaces/IMogulSmartWallet.sol";
import "./interfaces/IMovieVotingMasterChef.sol";
import "hardhat/console.sol";

contract MovieVoting is BasicMetaTransaction, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

    IERC20 public stars;
    IERC1155 public mglMovie;
    IMovieVotingMasterChef movieVotingMasterChef;
    uint256 public constant MAX_MOVIES = 5;

    enum VotingRoundState {Active, Paused, Canceled, Executed}

    struct UserMovieVotes {
        uint256 totalStarsEntered;
        bool rewardsClaimed;
    }

    struct VotingRound {
        uint256[MAX_MOVIES] movieIds;
        //uint256[MAX_MOVIES] votes;
        uint256 startVoteBlockNum;
        uint256 endVoteBlockNum;
        uint256 starsRewards;
        VotingRoundState votingRoundState;
        mapping(uint256 => uint256) votes;
        // mapping variables: userAddress, movieId
        mapping(address => mapping(uint256 => UserMovieVotes)) userMovieVotes;
    }

    VotingRound[] public votingRounds;

    event VotingRoundCreated(
        uint256[MAX_MOVIES] movieIds,
        uint256 startVoteBlockNum,
        uint256 endVoteBlockNum,
        uint256 starsRewards,
        uint256 votingRound
    );
    event VotingRoundPaused(uint256 roundId);
    event VotingRoundUnpaused(uint256 roundId);
    event VotingRoundCanceled(uint256 roundId);
    event VotingRoundExecuted(uint256 roundId);

    event Voted(
        address voter,
        uint256 roundId,
        uint256 movieId,
        uint256 starsAmountMantissa,
        uint256 quadraticVoteScore
    );
    event Unvoted(
        address voter,
        uint256 roundId,
        uint256 movieId,
        uint256 starsAmountMantissa,
        uint256 quadraticVoteScore
    );

    modifier onlyAdmin {
        require(hasRole(ROLE_ADMIN, msgSender()), "Sender is not admin");
        _;
    }

    modifier votingRoundMustExist(uint256 roundId) {
        require(
            roundId < votingRounds.length,
            "Voting Round id does not exist yet"
        );
        _;
    }

    constructor(
        address _admin,
        address _stars,
        address _mglMovie,
        address _movieVotingMasterChef
    ) public {
        _setupRole(ROLE_ADMIN, _admin);
        _setRoleAdmin(ROLE_ADMIN, ROLE_ADMIN);

        stars = IERC20(_stars);
        mglMovie = IERC1155(_mglMovie);
        movieVotingMasterChef = IMovieVotingMasterChef(_movieVotingMasterChef);
        // uint256(-1) is max number
        stars.approve(_movieVotingMasterChef, uint256(-1));
    }

    function getMovieIds(uint256 votingRoundId)
        public
        view
        returns (uint256[MAX_MOVIES] memory)
    {
        return votingRounds[votingRoundId].movieIds;
    }

    function getMovieVotes(uint256 votingRoundId)
        public
        view
        returns (uint256[MAX_MOVIES] memory)
    {
        VotingRound storage votingRound = votingRounds[votingRoundId];
        uint256[MAX_MOVIES] memory votes;
        for (uint256 i; i < MAX_MOVIES; i++) {
            votes[i] = (votingRound.votes[votingRound.movieIds[i]]);
        }
        return votes;
    }

    function getVotingRound(uint256 votingRoundId)
        public
        view
        returns (
            uint256[MAX_MOVIES] memory,
            uint256[MAX_MOVIES] memory,
            uint256,
            uint256,
            uint256,
            VotingRoundState
        )
    {
        VotingRound storage votingRound = votingRounds[votingRoundId];
        uint256[MAX_MOVIES] memory movieIds = votingRound.movieIds;
        uint256[MAX_MOVIES] memory votes;

        for (uint256 i; i < MAX_MOVIES; i++) {
            votes[i] = (votingRound.votes[votingRound.movieIds[i]]);
        }
        return (
            movieIds,
            votes,
            votingRound.startVoteBlockNum,
            votingRound.endVoteBlockNum,
            votingRound.starsRewards,
            votingRound.votingRoundState
        );
    }

    function getUserMovieVote(
        address userAddress,
        uint256 movieId,
        uint256 votingRoundId
    )
        public
        view
        returns (
            uint256,
            bool
        )
    {
        UserMovieVotes memory votingRound =
            votingRounds[votingRoundId].userMovieVotes[userAddress][movieId];
        return (
            votingRound.totalStarsEntered,
            votingRound.rewardsClaimed
        );
    }

    function createNewVotingRound(
        uint256[MAX_MOVIES] memory movieIds,
        uint256 startVoteBlockNum,
        uint256 endVoteBlockNum,
        uint256 starsRewards
    ) public onlyAdmin {
        require(
            startVoteBlockNum < endVoteBlockNum,
            "Start block must be less than end block"
        );
        VotingRound memory votingRound;
        votingRound.movieIds = movieIds;
        votingRound.startVoteBlockNum = startVoteBlockNum;
        votingRound.endVoteBlockNum = endVoteBlockNum;
        votingRound.starsRewards = starsRewards;
        votingRound.votingRoundState = VotingRoundState.Active;

        votingRounds.push(votingRound);

        stars.transferFrom(msgSender(), address(this), starsRewards);

        // transfer stars for rewards
        movieVotingMasterChef.add(
            startVoteBlockNum,
            endVoteBlockNum,
            starsRewards,
            false
        );

        emit VotingRoundCreated(
            movieIds,
            startVoteBlockNum,
            endVoteBlockNum,
            starsRewards,
            votingRounds.length
        );
    }

    function pauseVotingRound(uint256 roundId)
        public
        onlyAdmin
        votingRoundMustExist(roundId)
    {
        VotingRound storage votingRound = votingRounds[roundId];

        require(
            votingRound.votingRoundState == VotingRoundState.Active,
            "Only active voting rounds can be paused"
        );
        require(
            votingRound.endVoteBlockNum >= block.number,
            "Voting Round has already concluded"
        );
        votingRound.votingRoundState = VotingRoundState.Paused;

        emit VotingRoundPaused(roundId);
    }

    function unpauseVotingRound(uint256 roundId)
        public
        onlyAdmin
        votingRoundMustExist(roundId)
    {
        VotingRound storage votingRound = votingRounds[roundId];

        require(
            votingRound.votingRoundState == VotingRoundState.Paused,
            "Only paused voting rounds can be unpaused"
        );
        votingRound.votingRoundState = VotingRoundState.Active;

        emit VotingRoundUnpaused(roundId);
    }

    function cancelVotingRound(uint256 roundId)
        public
        onlyAdmin
        votingRoundMustExist(roundId)
    {
        VotingRound storage votingRound = votingRounds[roundId];

        require(
            votingRound.votingRoundState == VotingRoundState.Active ||
                votingRound.votingRoundState == VotingRoundState.Paused,
            "Only active or paused voting rounds can be cancelled"
        );
        require(
            block.number <= votingRound.endVoteBlockNum,
            "Voting Round has already concluded"
        );
        votingRound.votingRoundState = VotingRoundState.Canceled;

        emit VotingRoundCanceled(roundId);
    }

    function executeVotingRound(uint256 roundId)
        public
        onlyAdmin
        votingRoundMustExist(roundId)
    {
        VotingRound storage votingRound = votingRounds[roundId];

        require(
            votingRound.votingRoundState == VotingRoundState.Active,
            "Only active voting rounds can be executed"
        );
        require(
            votingRound.endVoteBlockNum < block.number,
            "Voting round has not ended"
        );
        votingRound.votingRoundState = VotingRoundState.Executed;

        emit VotingRoundExecuted(roundId);
    }

    function totalVotingRounds() public view returns (uint256) {
        return votingRounds.length;
    }

    function _verifySmartWalletOwner(
        bool isMogulSmartWallet,
        address mogulSmartWallet,
        address msgSender
    ) internal returns (address) {
        if (isMogulSmartWallet == true) {
            require(
                msgSender == IMogulSmartWallet(mogulSmartWallet).owner(),
                "Invalid Mogul Smart Wallet Owner"
            );
            return mogulSmartWallet;
        } else {
            return msgSender;
        }
    }

    function voteForMovie(
        uint256 roundId,
        uint256 movieId,
        uint256 starsAmountMantissa,
        bool isMogulSmartWallet,
        address mogulSmartWalletAddress
    ) public votingRoundMustExist(roundId) {
        require(
            starsAmountMantissa >= 1 ether,
            "Must deposit at least 1 Stars token"
        );

        address _msgSender =
            _verifySmartWalletOwner(
                isMogulSmartWallet,
                mogulSmartWalletAddress,
                msgSender()
            );

        VotingRound storage votingRound = votingRounds[roundId];
        UserMovieVotes storage userMovieVotes =
            votingRound.userMovieVotes[_msgSender][movieId];

        uint256[MAX_MOVIES] memory movieIds = votingRound.movieIds;
        require(
            movieId == movieIds[0] ||
                movieId == movieIds[1] ||
                movieId == movieIds[2] ||
                movieId == movieIds[3] ||
                movieId == movieIds[4],
            "Movie Id is not in voting round"
        );

        require(
            votingRound.votingRoundState == VotingRoundState.Active,
            "Can only vote in active rounds"
        );

        require(
            votingRound.startVoteBlockNum <= block.number &&
                block.number <= votingRound.endVoteBlockNum,
            "Voting round has not started or has ended"
        );

        //stars.transferFrom(_msgSender, address(this), starsAmountMantissa);

        userMovieVotes.totalStarsEntered = userMovieVotes.totalStarsEntered.add(
            starsAmountMantissa
        );

        uint256 quadraticVoteScore =
            userMovieVotes
                .totalStarsEntered
                .mul(userMovieVotes.totalStarsEntered)
                .div(1 ether)
                .div(1 ether);

        votingRound.votes[movieId] = votingRound.votes[movieId].add(
            quadraticVoteScore
        );

        //userMovieVotes.starsEntered.push(starsAmountMantissa);
        //userMovieVotes.blocksEntered.push(block.number);

        movieVotingMasterChef.deposit(roundId, starsAmountMantissa, _msgSender);

        emit Voted(
            _msgSender,
            roundId,
            movieId,
            starsAmountMantissa,
            quadraticVoteScore
        );
    }

    function removeVoteForMovie(
        uint256 roundId,
        uint256 movieId,
        uint256 starsAmountMantissa,
        bool isMogulSmartWallet,
        address mogulSmartWalletAddress
    ) public votingRoundMustExist(roundId) {
        require(starsAmountMantissa > 0, "Cannot remove 0 votes");

        address _msgSender =
            _verifySmartWalletOwner(
                isMogulSmartWallet,
                mogulSmartWalletAddress,
                msgSender()
            );

        VotingRound storage votingRound = votingRounds[roundId];
        UserMovieVotes storage userMovieVotes =
            votingRound.userMovieVotes[_msgSender][movieId];

        uint256[MAX_MOVIES] memory movieIds = votingRound.movieIds;
        require(
            movieId == movieIds[0] ||
                movieId == movieIds[1] ||
                movieId == movieIds[2] ||
                movieId == movieIds[3] ||
                movieId == movieIds[4],
            "Movie Id is not in voting round"
        );
        require(
            starsAmountMantissa <= userMovieVotes.totalStarsEntered,
            "Not enough Stars to remove"
        );
        require(
            votingRound.votingRoundState == VotingRoundState.Active,
            "Can only remove vote in active rounds"
        );

        require(
            votingRound.startVoteBlockNum <= block.number &&
                block.number <= votingRound.endVoteBlockNum,
            "Voting round has not started or ended"
        );

        userMovieVotes.totalStarsEntered = userMovieVotes.totalStarsEntered.sub(
            starsAmountMantissa
        );

        //uint256 currStarsAmountMantissa = starsAmountMantissa;
        //uint256 starsEnteredI = userMovieVotes.starsEntered.length;

        movieVotingMasterChef.emergencyWithdraw(roundId, _msgSender);
        //for (uint256 i = 1; i <= userMovieVotes.starsEntered.length; i++) {
        //    starsEnteredI = userMovieVotes.starsEntered.length - i;
        //    if (
        //        userMovieVotes.starsEntered[starsEnteredI] <=
        //        currStarsAmountMantissa
        //    ) {
        //        currStarsAmountMantissa = currStarsAmountMantissa.sub(
        //            userMovieVotes.starsEntered[starsEnteredI]
        //        );
        //        delete userMovieVotes.starsEntered[starsEnteredI];
        //        delete userMovieVotes.blocksEntered[starsEnteredI];
        //    } else {
        //        userMovieVotes.starsEntered[starsEnteredI] = userMovieVotes
        //            .starsEntered[starsEnteredI]
        //            .sub(currStarsAmountMantissa);

        //        break;
        //    }
        //}

        uint256 quadraticVoteScore =
            userMovieVotes
                .totalStarsEntered
                .mul(userMovieVotes.totalStarsEntered)
                .div(1 ether)
                .div(1 ether);

        votingRound.votes[movieId] = quadraticVoteScore;

        //stars.transfer(_msgSender, starsAmountMantissa);

        emit Unvoted(
            _msgSender,
            roundId,
            movieId,
            starsAmountMantissa,
            quadraticVoteScore
        );
    }

    function calculateStarsRewards(
        address userAddress,
        uint256 roundId,
        uint256 movieId
    ) public view votingRoundMustExist(roundId) returns (uint256) {
        VotingRound storage votingRound = votingRounds[roundId];
        UserMovieVotes storage userMovieVotes =
            votingRound.userMovieVotes[userAddress][movieId];

        return movieVotingMasterChef.pendingStars(roundId, userAddress);
    }

    function withdrawAndClaimStarsRewards(
        uint256 roundId,
        uint256 movieId,
        bool isMogulSmartWallet,
        address mogulSmartWalletAddress
    ) public votingRoundMustExist(roundId) {
        address _msgSender =
            _verifySmartWalletOwner(
                isMogulSmartWallet,
                mogulSmartWalletAddress,
                msgSender()
            );

        VotingRound storage votingRound = votingRounds[roundId];
        UserMovieVotes storage userMovieVotes =
            votingRound.userMovieVotes[_msgSender][movieId];
        require(
            userMovieVotes.rewardsClaimed == false,
            "Rewards have already been claimed"
        );

        userMovieVotes.rewardsClaimed = true;

        movieVotingMasterChef.withdraw(roundId, _msgSender);
        //uint256 starsRewards =
        //    calculateStarsRewards(_msgSender, roundId, movieId);

        //stars.transfer(
        //    _msgSender,
        //    starsRewards.add(userMovieVotes.totalStarsEntered)
        //);
    }
}