pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.7/VRFConsumerBase.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IZooFunctions.sol";
import "./ZooGovernance.sol";

/// @title NftBattleArena contract.
/// @notice Contract for staking ZOO-Nft for participate in battle votes.
contract NftBattleArena is Ownable
{
	using SafeMath for uint256;
	
	ERC20 public zoo;                      // Zoo token interface.
	ERC20 public dai;                      // DAI token interface
	VaultAPI public vault;                 // Yearn interface.
	ZooGovernance public zooGovernance;    // zooGovernance contract.
	IZooFunctions public zooFunctions;     // zooFunctions contract.

	/// @notice Struct for stages of vote battle.
	enum Stage
	{
		FirstStage,
		SecondStage,
		ThirdStage,
		FourthStage
	}

	/// @notice Struct for vote records.
	struct VoteRecord
	{
		uint256 daiInvested;           // Amount of DAI invested.
		uint256 yTokensNumber;         // amount of yTokens.
		uint256 zooInvested;           // Amount of Zoo invested.
		uint256 votes;                 // Amount of votes.
		bool daiHaveWithdrawed;        // Returns true if Dai were withdrawed.
		bool zooHaveWithdrawed;        // Returns true if Zoo were withdrawed.
	}

	/// @notice Struct for records about staked Nfts.
	struct NftRecord
	{
		address token;                 // Address of Nft contract.
		uint256 id;                    // Id of Nft.
		uint256 votes;                 // Amount of votes for this Nft.
	}

	// Struct for records about pairs of Nfts for battle.
	struct NftPair
	{
		address token1;                // Address of Nft contract of 1st Nft candidate.
		uint256 id1;                   // Id of 1st Nft candidate.
		address token2;                // Address of Nft contract of 2nd Nft candidate.
		uint256 id2;                   // Id of 2nd Nft candidate.
		bool win;                      // Boolean where true is when 1st candidate wins, and false for 2nd.
	}

	/// @notice Event records address of allowed nft contract.
	/// @param token - address of contract.
	event newContractAllowed (address token);

	/// @notice Event records info about staked nft in this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	event StakedNft(address indexed staker, address indexed token, uint256 indexed id);

	/// @notice Event records info about withdrawed nft from this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	event WithdrawedNft(address staker, address indexed token, uint256 indexed id);

	/// @notice Event records info about vote using Dai.
	/// @param voter - address voter.
	/// @param token - address of token contract.
	/// @param id - id of nft.
	/// @param amount - amount of votes.
	event VotedWithDai(address voter, address indexed token, uint256 indexed id, uint256 amount);

	/// @notice Event records info about vote using Zoo.
	/// @param voter - address voter.
	/// @param token - address of token contract.
	/// @param id - id of nft.
	/// @param amount - amount of votes.
	event VotedWithZoo(address voter, address indexed token, uint256 indexed id, uint256 amount);

	/// @notice Event records info about reVote again using Zoo.
	/// @param epoch - epoch number
	/// @param token - address of token contract.
	/// @param id - id of nft.
	/// @param votes - amount of votes.
	event ReVotedWithZoo(uint256 indexed epoch, address indexed token, uint256 indexed id, uint256 votes);

	/// @notice Event records info about reVote again using Dai
	/// @param epoch - epoch number
	/// @param token - address of token contract.
	/// @param id - id of nft.
	/// @param votes - amount of votes.
	event ReVotedWithDai(uint256 indexed epoch, address indexed token, uint256 indexed id, uint256 votes);

	/// @notice Event records info about claimed reward for staker.
	/// @param staker -address staker.
	/// @param epoch - epoch number.
	/// @param token - address token.
	/// @param id - id of nft.
	/// @param income - amount of reward.
	event StakerRewardClaimed(address staker, uint256 indexed epoch, address indexed token, uint256 indexed id, uint256 income);

	/// @notice Event records info about claimed reward for voter.
	/// @param staker - address staker.
	/// @param epoch - epoch number.
	/// @param token - address token.
	/// @param id - id of nft.
	/// @param income - amount of reward.
	event VoterRewardClaimed(address staker, uint256 indexed epoch, address indexed token, uint256 indexed id, uint256 income);

	/// @notice Event records info about withdrawed dai from votes.
	/// @param staker - address staker.
	/// @param epoch - epoch number.
	/// @param token - address token.
	/// @param id - id of nft.
	event WithdrawedDai(address staker, uint256 indexed epoch, address indexed token, uint256 indexed id);

	/// @notice Event records info about withdrawed Zoo from votes.
	/// @param staker - address staker.
	/// @param epoch - epoch number.
	/// @param token - address token.
	/// @param id - id of nft.
	event WithdrawedZoo(address staker, uint256 indexed epoch, address indexed token, uint256 indexed id);

	/// @notice Event records info about nft paired for vote battle.
	/// @param date - date of function call.
	/// @param participants - amount of participants for vote battles.
	event NftPaired(uint256 currentEpoch, uint256 date, uint256 participants);

	/// @notice Event records info about winners in battles.
	/// @param currentEpoch - number of currentEpoch.
	/// @param i - index of battle.
	/// @param random - random number get for calculating winner.
	event Winner(uint256 currentEpoch, uint256 i, uint256 random);

	
	uint256 public totalNftsInEpoch;               // Amount of Nfts staked.

	uint256 public epochStartDate;                 // Start date of battle contract.
	uint256 public currentEpoch = 0;               // Counter for battle epochs.

	uint256 public firstStageDuration = 5 minutes;		//todo:change time //3 days;    // Duration of first stage.
	uint256 public secondStageDuration = 5 minutes;		//todo:change time//7 days;   // Duration of second stage.
	uint256 public thirdStageDuration = 5 minutes;		//todo:change time//5 days;    // Duration third stage.
	uint256 public fourthStage = 5 minutes;		//todo:change time//2 days;           // Duration of fourth stage.
	uint256 public epochDuration = firstStageDuration + secondStageDuration + thirdStageDuration + fourthStage; // Total duration of battle epoch.

	// Epoch => address of NFT => id => VoteRecord
	mapping (uint256 => mapping(address => mapping(uint256 => VoteRecord))) public votesForNftInEpoch;

	// Epoch => address of NFT => id => investor => VoteRecord
	mapping (uint256 => mapping(address => mapping(uint256 => mapping(address => VoteRecord)))) public investedInVoting;

	// Epoch => address of NFT => id => voter => is voter rewarded?
	mapping (uint256 => mapping(address => mapping(uint256 => mapping(address => bool)))) public isVoterRewarded; // Returns true if reward claimed.

	// Epoch => address of NFT => id => incomeFromInvestment
	mapping (uint256 => mapping(address => mapping(uint256 => uint256))) public incomeFromInvestments;

	// Epoch => address of NFT => id => is staker rewarded?
	mapping (uint256 => mapping(address => mapping(uint256 => bool))) public isStakerRewared;   // Returns true if reward claimed.

	// Epoch => dai deposited in epoch.
	mapping (uint256 => uint256) public daiInEpochDeposited;                // Records amount of dai deposited in epoch.

	// Epoch => zoo deposited in epoch.
	mapping (uint256 => uint256) public zooInEpochDeposited;                // Records amount of Zoo deposited in epoch.

	// Nft contract => allowed or not.
	mapping (address => bool) public allowedForStaking;                     // Records NFT contracts available for staking.

	// nft contract => nft id => address staker.
	mapping (address => mapping (uint256 => address)) public tokenStakedBy; // Records that nft staked or not.

	// epoch number => amount of nfts.
	mapping (uint256 => NftRecord[]) public nftsInEpoch;                    // Records amount of nft in battle epoch.

	// epoch number => amount of pairs of nfts.
	mapping (uint256 => NftPair[]) public pairsInEpoch;                     // Records amount of pairs in battle epoch.

	// epoch number => truncateAndPair called or not.
	mapping (uint256 => bool) public truncateAndPaired;                     // Records if participants were paired.

	// contract address => amount of nft.
	mapping(address => uint256) public thisContractNftsAmount;

	/// @notice Contract constructor.
	/// @param _zoo - address of Zoo token contract.
	/// @param _dai - address of DAI token contract.
	/// @param _vault - address of yearn
	/// @param _zooGovernance - address of ZooDao Governance contract.
	constructor (address _zoo, address _dai, address _vault, address _zooGovernance) Ownable()
	{
		zoo = ERC20(_zoo);
		dai = ERC20(_dai);
		vault = VaultAPI(_vault);
		zooGovernance = ZooGovernance(_zooGovernance);

		epochStartDate = block.timestamp;//todo:change time for prod +  14 days;                              // Start date of 1st battle.
	}

	/// @notice Function for updating functions according last governance resolutions.
	function updateZooFunctions() external onlyOwner
	{
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!"); // Requires to be at first stage in battle epoch.

		zooFunctions = IZooFunctions(zooGovernance.zooFunctions());              // Sets ZooFunctions to contract specified in zooGovernance.
	}

	/// @notice Function to allow new NFT contract available for stacking.
	/// @param token - address of new Nft contract.
	function allowNewContractForStaking(address token) external onlyOwner
	{
		allowedForStaking[token] = true;                                         // Boolean for contract to be allowed for staking.

		emit newContractAllowed(token);
	}

	/// @notice Function for staking NFT in this pool.
	/// @param token - address of Nft token to stake
	/// @param id - id of nft token
	function stakeNft(address token, uint256 id) public
	{
		require(allowedForStaking[token] = true, "Nft not allowed!");             // Requires for nft-token to be from allowed contract.
		require(tokenStakedBy[token][id] == address(0), "Already staked!");       // Requires for token to be non-staked before.
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!");  // Requires to be at first stage in battle epoch.

		IERC721(token).transferFrom(msg.sender, address(this), id);               // Sends NFT token to this contract.

		tokenStakedBy[token][id] = msg.sender;                                    // Records that token now staked.
		
		thisContractNftsAmount[token]++;
		totalNftsInEpoch++;
		
		emit StakedNft(msg.sender, token, id);                                    // Emits StakedNft event.
	}

	/// @notice Function for withdrawal Nft token back to owner.
	/// @param token - address of Nft token to unstake.
	/// @param id - id of nft token.
	function withdrawNft(address token, uint256 id) public
	{
		require(tokenStakedBy[token][id] == msg.sender, "Must be staked by you!");// Requires for token to be staked in this contract.
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!");  // Requires to be at first stage in battle epoch.

		IERC721(token).transferFrom(address(this), msg.sender, id);               // Transfers token back to owner.

		tokenStakedBy[token][id] = address(0);                                    // Records that token is unstaked.
		
		thisContractNftsAmount[token]--;
		totalNftsInEpoch--;
		
		emit WithdrawedNft(msg.sender, token, id);                                // Emits withdrawedNft event.
	}

	/// @notice Function for voting with DAI in battle epoch.
	/// @param token - address of Nft token voting for.
	/// @param id - id of voter.
	/// @param amount - amount of votes in DAI.
	/// @return votes - calculated amount of votes from dai for nft.
	function voteWithDai(address token, uint256 id, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.SecondStage, "Must be at 2nd stage!");   // Requires to be at second stage of battle epoch.
		require(tokenStakedBy[token][id] != address(0), "Must be staked!");
		dai.transferFrom(msg.sender, address(this), amount);                        // Transfers DAI to this contract for vote.

		votes = zooFunctions.computeVotesByDai(amount);                             // Calculates amount of votes.

		dai.approve(address(vault), amount);                                        // Approves Dai for address of yearn vault for amount
		uint256 yTokensNumber = vault.deposit(amount);                              // deposits to yearn vault and record yTokens.

		votesForNftInEpoch[currentEpoch][token][id].votes += votes;                 // Adds amount of votes for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].daiInvested += amount;          // Adds amount of Dai invested for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].yTokensNumber += yTokensNumber; // Adds amount of yTokens invested for this epoch, contract and id.

		investedInVoting[currentEpoch][token][id][msg.sender].daiInvested += amount;// Adds amount of Dai invested for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][msg.sender].votes += votes;       // Adds amount of votes for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][msg.sender].yTokensNumber += yTokensNumber;// Adds amount of yToken invested for this epoch, contract and id for msg.sender.

		uint256 length = nftsInEpoch[currentEpoch].length;                          // Sets amount of Nfts in current epoch.

		daiInEpochDeposited[currentEpoch] += amount;                                // Adds amount of Dai deposited in current epoch.

		emit VotedWithDai(msg.sender, token, id, amount);                           // Records in VotedWithDai event.

		uint256 i;
		for (i = 0; i < length; i++)
		{
			if (nftsInEpoch[currentEpoch][i].token == token && nftsInEpoch[currentEpoch][i].id == id)
			{
				nftsInEpoch[currentEpoch][i].votes += votes;
				break;
			}
		}

		if (i == length)
		{
			nftsInEpoch[currentEpoch].push(NftRecord(token, id, votes));
		}

		return votes;
	}

	/// @notice Function for making battle pairs.
	/// @return success - returns true for success.
	function truncateAndPair() public returns (bool success)
	{
		require(getCurrentStage() == Stage.ThirdStage || getCurrentStage() == Stage.FourthStage, "Must be at 3rd or 4th stage!");          // Requires to be at 3rd stage of battle epoch.
		require(nftsInEpoch[currentEpoch].length != 0, "Already paired!");

		emit NftPaired(currentEpoch, block.timestamp, nftsInEpoch[currentEpoch].length);

		truncateAndPaired[currentEpoch] = true;

		if (nftsInEpoch[currentEpoch].length % 2 == 1)                                    // If number of nft participants is odd.
		{
			uint256 random = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1)))); // Generate random number.
			uint256 index = random % nftsInEpoch[currentEpoch].length;                    // Pick random participant.
			uint256 length = nftsInEpoch[currentEpoch].length;                            // Get list of participants.
			nftsInEpoch[currentEpoch][index] = nftsInEpoch[currentEpoch][length - 1];     // Truncate list.
			nftsInEpoch[currentEpoch].pop();                                              // Remove random unused participant from list.
		}

		uint256 i = 1;

		while (nftsInEpoch[currentEpoch].length != 0)                                     // Get pairs of nft until where are zero left in list.
		{
			uint256 length = nftsInEpoch[currentEpoch].length;                            // Get list.

			uint256 random1 = uint256(keccak256(abi.encodePacked(uint256(blockhash(block.number - 1)) + i++))) % length; // Generate random number.
			uint256 random2 = uint256(keccak256(abi.encodePacked(uint256(blockhash(block.number - 1)) + i++))) % length; // Generate 2nd random number.

			address token1 = nftsInEpoch[currentEpoch][random1].token; // Pick random nft contract address.
			uint256 id1 = nftsInEpoch[currentEpoch][random1].id;       // Pick random nft id.

			address token2 = nftsInEpoch[currentEpoch][random2].token; // Pick random nft contract address.
			uint256 id2 = nftsInEpoch[currentEpoch][random2].id;       // Pick random nft id.

			pairsInEpoch[currentEpoch].push(NftPair(token1, id1, token2, id2, false));  // Push pair.

			nftsInEpoch[currentEpoch][random1] = nftsInEpoch[currentEpoch][length - 1];
			nftsInEpoch[currentEpoch][random2] = nftsInEpoch[currentEpoch][length - 2];

			nftsInEpoch[currentEpoch].pop();                           // Remove from array.
			nftsInEpoch[currentEpoch].pop();                           // Remove from array.
		}
		return true;
	}

	/// @notice Function for boost\multiply votes with Zoo.
	/// @param token - address of nft.
	/// @param id - id of voter.
	/// @param amount - amount of Zoo.
	/// @return votes - amount of votes.
	function voteWithZoo(address token, uint256 id, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.ThirdStage, "Must be at 3rd stage!");      // Requires to be at 3rd stage.
		require(tokenStakedBy[token][id] != address(0), "Must be staked!");           // Requires to vote for staked nft.
		zoo.transferFrom(msg.sender, address(this), amount);                          // Transfers Zoo from sender to this contract.

		votes = zooFunctions.computeVotesByZoo(amount);                               // Calculates amount of votes.

		require(votes <= investedInVoting[currentEpoch][token][id][msg.sender].votes, "votes amount more than invested!"); // Reverts if votes more than tokens invested.

		votesForNftInEpoch[currentEpoch][token][id].votes += votes;                   // Adds votes for this epoch, token and id.
		votesForNftInEpoch[currentEpoch][token][id].zooInvested += amount;            // Adds amount of Zoo for this epoch, token and id.

		investedInVoting[currentEpoch][token][id][msg.sender].votes += votes;         // Adds votes for this epoch, token and id for msg.sender.
		investedInVoting[currentEpoch][token][id][msg.sender].zooInvested += amount;  // Adds amount of Zoo for this epoch, token and id for msg.sender.
		zooInEpochDeposited[currentEpoch] += amount;                                  // Adds amount of zoo deposited in current epoch.
		
		emit VotedWithZoo(msg.sender, token, id, amount);                             // Records in VotedWithZoo event.

		return votes;
	}

	/// @notice Function for chosing winner.
	/// @dev should be changed for chainlink VRF. TODO:
	function chooseWinners() public
	{
		require(getCurrentStage() == Stage.FourthStage, "Must be at 4th stage!");    // Requires to be at 4th stage.

		require(truncateAndPaired[currentEpoch] = true, "Must be paired before choosing!");

		for (uint256 i = 0; i < pairsInEpoch[currentEpoch].length; i++)
		{
			uint256 random = zooFunctions.getRandomNumber(i);                        // Get random number.

			address token1 = pairsInEpoch[currentEpoch][i].token1;                   // Address of 1st candidate.
			uint256 id1 = pairsInEpoch[currentEpoch][i].id1;                         // Id of 1st candidate.
			uint256 votesForA = votesForNftInEpoch[currentEpoch][token1][id1].votes; // Votes for 1st candidate.
			
			address token2 = pairsInEpoch[currentEpoch][i].token2;                   // Address of 2nd candidate.
			uint256 id2 = pairsInEpoch[currentEpoch][i].id2;                         // Id of 2nd candidate.
			uint256 votesForB = votesForNftInEpoch[currentEpoch][token2][id2].votes; // Votes for 2nd candidate.

			pairsInEpoch[currentEpoch][i].win = zooFunctions.decideWins(votesForA, votesForB, random); // Calculates winner and records it.

			uint256 undeposited1 = vault.withdraw(_sharesToTokens(votesForNftInEpoch[currentEpoch][token1][id1].yTokensNumber)); // Withdraws tokens from yearn vault for 1st candidate.
			uint256 undeposited2 = vault.withdraw(_sharesToTokens(votesForNftInEpoch[currentEpoch][token2][id2].yTokensNumber)); // Withdraws tokens from yearn vault for 2nd candidate.

			uint256 income = (undeposited1.add(undeposited2)).sub(votesForNftInEpoch[currentEpoch][token1][id1].daiInvested).sub(votesForNftInEpoch[currentEpoch][token2][id2].daiInvested); // Calculates income.

			if (pairsInEpoch[currentEpoch][i].win)                                   // If 1st candidate wins.
			{
				incomeFromInvestments[currentEpoch][token1][id1] = income;           // Records income to 1st candidate.
			}
			else                                                                     // If 2nd candidate wins.
			{
				incomeFromInvestments[currentEpoch][token2][id2] = income;           // Records income to 2nd candidate.
			}
			emit Winner(currentEpoch, i, random);                                    // Records in Winner event.
		}

		epochStartDate = block.timestamp + fourthStage;                              // Sets start of new epoch.
		currentEpoch++;                                                              // Increments currentEpoch.
	}

	/// @notice Function for claiming reward for Nft stakers.
	/// @param epoch - number of epoch.
	/// @param token - address of nft contract.
	/// @param id - Id of nft.
	function claimRewardForStakers(uint256 epoch, address token, uint256 id) public
	{
		require(tokenStakedBy[token][id] == msg.sender, "Must be staked by msg.sender!"); // Requires for token to be staked by msg.sender.
		require(!isStakerRewared[epoch][token][id], "Already rewarded!");           // Requires to be not rewarded before.

		uint256 income = incomeFromInvestments[epoch][token][id];                   // Gets income amount for this epoch, token and id.

		if (income != 0)
		{
			dai.transfer(msg.sender, income.mul(2).div(100));                       // Transfers Dai to msg.sender for 2% from income
		}

		isStakerRewared[epoch][token][id] = true;                                   // Records that staker was rewarded.

		emit StakerRewardClaimed(msg.sender, epoch, token, id, income);             // Records in StakerRewardClaimed event. 
	}

	/// @notice Function for claiming rewards for voter.
	/// @param epoch - number of epoch when voted.
	/// @param token - address of contract nft voted for.
	/// @param id - Id of nft voted for.
	function claimRewardForVoter(uint256 epoch, address token, uint256 id) public
	{
		require(!isVoterRewarded[epoch][token][id][msg.sender], "Already rewarded!");// Requires to be not rewarded before.

		uint256 votes = investedInVoting[epoch][token][id][msg.sender].votes;        // Gets amount of votes for this epoch, nft, id from msg.sender.
		uint256 income = incomeFromInvestments[epoch][token][id];                    // Gets income amount for this epoch, token and id.
		uint256 totalVotes = votesForNftInEpoch[epoch][token][id].votes;             // Gets amount of total votes for this nft in this epoch.

		if (income != 0)
			dai.transfer(msg.sender, (((income.mul(98)).mul(votes)).div(100)).div(totalVotes)); // Transfers reward.

		isVoterRewarded[epoch][token][id][msg.sender] = true;                        // Records what voter has been rewarded.

		emit VoterRewardClaimed(msg.sender, epoch, token, id, income);               // Records in VoterRewardClaimed event. 
	}
	
	/// @notice Function to view pending rewards for voter.
	/// @param epoch - epoch number.
	/// @param token - token address.
	/// @param id - id of token.
	/// @return pendingReward - pending reward from this battle.
	function getPendingVoterRewards(uint256 epoch, address token, uint256 id) public view returns(uint256 pendingReward) {
		uint256 votes = investedInVoting[epoch][token][id][msg.sender].votes;        // Gets amount of votes for this epoch, nft, id from msg.sender.
		uint256 income = incomeFromInvestments[epoch][token][id];                    // Gets income amount for this epoch, token and id.
		uint256 totalVotes = votesForNftInEpoch[epoch][token][id].votes;             // Gets amount of total votes for this nft in this epoch.
		pendingReward = (((income.mul(98)).mul(votes)).div(100)).div(totalVotes);
	}

	/// @notice Function to view pending rewards for staker.
	/// @param epoch - epoch number.
	/// @param token - token address.
	/// @param id - id of token.
	/// @return pendingReward - pending reward from this battle.
	function getPendingStakerReward(uint256 epoch, address token, uint256 id) public view returns(uint256 pendingReward) {
		uint256 income = incomeFromInvestments[epoch][token][id];                   // Gets income amount for this epoch, token and id.
		pendingReward = (income.mul(2)).div(100);
	}

	/// @notice Function for withdraw Dai from votes.
	/// @param epoch - epoch number.
	/// @param token - address of nft contract.
	/// @param id - id of nft.
	function withdrawDai(uint256 epoch, address token, uint256 id) public
	{
		require(epoch < currentEpoch, "Not in current epoch!");                               // Withdraw allowed from previous epochs.
		require(!investedInVoting[epoch][token][id][msg.sender].daiHaveWithdrawed, "Dai tokens were withdrawed!"); // Requires for tokens to be not withdrawed or reVoted yet.

		dai.transfer(msg.sender, investedInVoting[epoch][token][id][msg.sender].daiInvested); // Transfers dai.

		investedInVoting[epoch][token][id][msg.sender].daiHaveWithdrawed = true;              // Records that tokens were reVoted.

		emit WithdrawedDai(msg.sender, epoch, token, id);                                     // Records in WithdrawedDai event.
	}

	/// @notice Function for withdraw Zoo from votes.
	/// @param epoch - epoch number.
	/// @param token - address of nft contract.
	/// @param id - id of nft.
	function withdrawZoo(uint256 epoch, address token, uint256 id) public
	{
		require(epoch < currentEpoch, "Not in current epoch!");                  // Withdraw allowed from previous epochs.
		require(!investedInVoting[epoch][token][id][msg.sender].zooHaveWithdrawed,"Zoo tokens were withdrawed!");// Requires for tokens to be not withdrawed or reVoted yet.

		zoo.transfer(msg.sender, investedInVoting[epoch][token][id][msg.sender].zooInvested); // Transfers Zoo.

		investedInVoting[epoch][token][id][msg.sender].zooHaveWithdrawed = true; // Records that tokens were reVoted.

		emit WithdrawedZoo(msg.sender, epoch, token, id);                        // Records in WithdrawedZoo event.
	}

	/// @notice Function for repeat vote using Dai in next battle epoch.
	/// @param epoch - number of epoch vote was made.
	/// @param token - address of nft contract vote was made for.
	/// @param id - id of nft vote was made for.
	/// @param voter - address of votes owner.
	function reVoteInDai(uint256 epoch, address token, uint256 id, address voter) public
	{
		require(getCurrentStage() == Stage.SecondStage, "Must be at 2nd stage!");   // Requires to be at second stage of battle epoch.
		require(!investedInVoting[epoch - 1][token][id][voter].daiHaveWithdrawed, "dai tokens were withdrawed!"); // Requires for tokens to be not withdrawed or reVoted yet.

		uint256 amount = investedInVoting[epoch - 1][token][id][voter].daiInvested; // Get amount of votes from previous epoch.
		require(amount != 0, "nothing to re-vote!");                                // Requires for amount of votes to be non zero.
		uint256 votes = zooFunctions.computeVotesByDai(amount);                     // Calculates amount of votes.

		dai.approve(address(vault), amount);                                        // Approves Dai for address of yearn vault for amount
		uint256 yTokensNumber = vault.deposit(amount);                              // Records number of Dai transfered to yearn vault.

		votesForNftInEpoch[currentEpoch][token][id].votes += votes;                 // Adds amount of votes for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].daiInvested += amount;          // Adds amount of Dai invested for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].yTokensNumber += yTokensNumber; // Adds amount of yTokens invested for this epoch, contract and id.

		investedInVoting[currentEpoch][token][id][voter].daiInvested += amount;     // Adds amount of Dai invested for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][voter].votes += votes;            // Adds amount of votes for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][voter].yTokensNumber += yTokensNumber;// Adds amount of yToken invested for this epoch, contract and id for msg.sender.

		uint256 length = nftsInEpoch[currentEpoch].length;                          // Sets amount of Nfts in current epoch.

		daiInEpochDeposited[currentEpoch] += amount;                                // Adds amount of Dai deposited in current epoch.

		uint256 i;
		for (i = 0; i < length; i++)
		{
			if (nftsInEpoch[currentEpoch][i].token == token && nftsInEpoch[currentEpoch][i].id == id)
			{
				nftsInEpoch[currentEpoch][i].votes += votes;
				break;
			}
		}

		if (i == length)
		{
			nftsInEpoch[currentEpoch].push(NftRecord(token, id, votes));
		}

		investedInVoting[epoch - 1][token][id][msg.sender].daiHaveWithdrawed = true;

		emit ReVotedWithDai(epoch, token, id, votes);                               // Records in ReVotedWithDai event.
	}

	/// @notice Function for repeat vote using Zoo in next battle epoch.
	/// @param epoch - number of epoch vote was made.
	/// @param token - address of nft contract vote was made for.
	/// @param id - id of nft vote was made for.
	/// @param voter - address of votes owner.
	function reVoteInZoo(uint256 epoch, address token, uint256 id, address voter) public
	{
		require(getCurrentStage() == Stage.ThirdStage, "Must be at 3rd stage!");
		require(!investedInVoting[epoch - 1][token][id][voter].zooHaveWithdrawed, "Zoo tokens were withdrawed!");
		uint256 amount = investedInVoting[epoch - 1][token][id][voter].zooInvested;
		require(amount != 0, "nothing to re-vote!");

		uint256 votes = zooFunctions.computeVotesByZoo(amount);                 // Calculates amount of votes.

		require(votes <= investedInVoting[currentEpoch][token][id][voter].votes, "votes amount more than invested!"); // Reverts if votes more than tokens invested.

		votesForNftInEpoch[currentEpoch][token][id].votes += votes;             // Adds votes for this epoch, token and id.
		votesForNftInEpoch[currentEpoch][token][id].zooInvested += amount;      // Adds amount of Zoo for this epoch, token and id.

		investedInVoting[currentEpoch][token][id][voter].votes += votes;        // Adds votes for this epoch, token and id for msg.sender.
		investedInVoting[currentEpoch][token][id][voter].zooInvested += amount; // Adds amount of Zoo for this epoch, token and id for msg.sender.

		investedInVoting[epoch - 1][token][id][voter].zooHaveWithdrawed = true; // Records that tokens were reVoted.

		emit ReVotedWithZoo(epoch, token, id, votes);                           // Records in ReVotedWithZoo event.
	}

	/// @notice Function calculate amount of shares.
	/// @param _sharesAmount - amount of shares.
	/// @return shares - calculated amount of shares.
	function _sharesToTokens(uint256 _sharesAmount) public view returns (uint256 shares) ///todo:make internal
	{
		return _sharesAmount.mul(vault.pricePerShare()).div(10 ** dai.decimals()); // Calculate amount of shares.
	}

	/// @notice Function to view current stage in battle epoch.
	/// @return stage - current stage.
	function getCurrentStage() public view returns (Stage)
	{
		if (block.timestamp < epochStartDate + firstStageDuration)
		{
			return Stage.FirstStage;
		}
		else if (block.timestamp < epochStartDate + firstStageDuration + secondStageDuration)
		{
			return Stage.SecondStage;
		}
		else if (block.timestamp < epochStartDate + firstStageDuration + secondStageDuration + thirdStageDuration)
		{
			return Stage.ThirdStage;
		}
		else
		{
			return Stage.FourthStage;
		}
	}
}