pragma solidity ^0.7.0;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@chainlink/contracts/src/v0.7/VRFConsumerBase.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IZooFunctions.sol";
import "./ZooGovernance.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title NftBattleArena contract.
/// @notice Contract for staking ZOO-Nft for participate in battle votes.
contract NftBattleArena is Ownable, ERC721
{
	using SafeMath for uint256;
	using SafeMath for int256;
	using Math for uint256;
	using Math for int256;
	
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

	/// @notice Struct with type of positions for staker and voter.
	enum PositionType
	{
		StakerPostion,
		VoterPosition
	}

	/// @notice Struct with info about rewards mechanic.
	struct BattleReward
	{
		int256 yTokensSaldo; // saldo from deposit in yearn in yTokens.
		uint256 votes;       // amount of votes.
		uint256 yTokens;     // amount of yTokens.
		uint256 tokensAtBattleStart; // amount of yTokens at start.
	}

	/// @notice Struct with info about staker positions.
	struct StakerPosition
	{
		address token;      // Token address.
		uint256 id;         // Token id.
		uint256 startEpoch; // Epoch when started to stake.
		uint256 endEpoch;   // Epoch when ended to stake.
		uint256 lastRewardedEpoch;
		mapping (uint256 => BattleReward) rewards; // Records rewards part.
	}

	// /// @notice Struct with info about vote.
	// struct VoteRecord
	// {
	// 	uint256 daiInvested;           // Amount of DAI invested.
	// 	uint256 yTokensNumber;         // amount of yTokens.
	// 	uint256 zooInvested;           // Amount of Zoo invested.
	// 	uint256 votes;                 // Amount of votes.
	// 	bool daiHaveWithdrawed;        // Returns true if Dai were withdrawed.
	// 	bool zooHaveWithdrawed;        // Returns true if Zoo were withdrawed.
	// }

	/// @notice struct with info about voter positions.
	struct VotingPosition
	{
		uint256 stakingPositionId;
		uint256 daiInvested;
		uint256 yTokensNumber;
		uint256 zooInvested;
		uint256 daiVotes;
		uint256 votes;
		uint256 startDate;
		uint256 endDate;
		uint256 startEpoch;
		uint256 endEpoch;
		uint lastRewardedEpoch;
	}

/*	/// @notice Struct for records about staked Nfts.
	struct NftRecord
	{
		address token;                 // Address of Nft contract.
		uint256 id;                    // Id of Nft.
		//uint256 votes;                 // Amount of votes for this Nft.
	}*/

	/// @notice Struct for records about pairs of Nfts for battle.
	struct NftPair
	{
		uint256 token1;
		uint256 token2;
		bool playedInEpoch;
		bool win;                      // Boolean where true is when 1st candidate wins, and false for 2nd.
	}

	/// @notice Event records address of allowed nft contract.
	/// @param token - address of contract.
	event newContractAllowed (address token);

	/// @notice Event records info about staked nft in this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	event StakedNft(address indexed staker, address indexed token, uint256 indexed id, uint256 positionId);

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
	/// @param positionId - id of nft.
	/// @param amount - amount of votes.
	event VotedWithZoo(address voter, uint256 indexed positionId, uint256 amount);

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
	event WithdrawedDai(address staker, uint256 indexed epoch, address indexed token, uint256 indexed id, uint256 amount);

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

	uint256 public firstStageDuration = 7 minutes;		//todo:change time //3 days;    // Duration of first stage.
	uint256 public secondStageDuration = 7 minutes;		//todo:change time//7 days;   // Duration of second stage.
	uint256 public thirdStageDuration = 7 minutes;		//todo:change time//5 days;    // Duration third stage.
	uint256 public fourthStage = 7 minutes;		//todo:change time//2 days;           // Duration of fourth stage.
	uint256 public epochDuration = firstStageDuration + secondStageDuration + thirdStageDuration + fourthStage; // Total duration of battle epoch.

	// Epoch => address of NFT => id => VoteRecord
	// mapping (uint256 => mapping(address => mapping(uint256 => VoteRecord))) public votesForNftInEpoch;

	// Epoch => address of NFT => id => investor => VoteRecord
	// mapping (uint256 => mapping(address => mapping(uint256 => mapping(address => VoteRecord)))) public investedInVoting;

	// Epoch => address of NFT => id => voter => is voter rewarded?
	// mapping (uint256 => mapping(address => mapping(uint256 => mapping(address => bool)))) public isVoterRewarded; // Returns true if reward claimed.

	// Epoch => address of NFT => id => incomeFromInvestment
	// mapping (uint256 => mapping(address => mapping(uint256 => uint256))) public incomeFromInvestments;

	// Epoch => address of NFT => id => is staker rewarded?
	// mapping (uint256 => mapping(address => mapping(uint256 => bool))) public isStakerRewared;   // Returns true if reward claimed.

	// Epoch => dai deposited in epoch.
	// mapping (uint256 => uint256) public daiInEpochDeposited;                // Records amount of dai deposited in epoch.

	// Epoch => zoo deposited in epoch.
	mapping (uint256 => uint256) public zooInEpochDeposited;                // Records amount of Zoo deposited in epoch.

	// Nft contract => allowed or not.
	mapping (address => bool) public allowedForStaking;                     // Records NFT contracts available for staking.

	// nft contract => nft id => address staker.
	// mapping (address => mapping (uint256 => address)) public tokenStakedBy; // Records that nft staked or not.

	// epoch number => amount of nfts.
	mapping (uint256 => uint256[]) public nftsInEpoch;                    // Records amount of nft in battle epoch.

	// epoch number => amount of pairs of nfts.
	mapping (uint256 => NftPair[]) public pairsInEpoch;                     // Records amount of pairs in battle epoch.

	// epoch number => number of played pairs in epoch;
	mapping (uint256 => uint256) public numberOfPlayedPairsInEpoch;

	// epoch number => truncateAndPair called or not.
	mapping (uint256 => bool) public truncateAndPaired;                     // Records if participants were paired.

	mapping (uint256 => PositionType) public positions;

	mapping (uint256 => StakerPosition) public stakingPositions;

	mapping (uint256 => VotingPosition) public votingPositions;

	uint256 public numberOfPositions;

	uint256[] public nfts;

	uint256 public nftsInGame;

	/// @notice Contract constructor.
	/// @param _zoo - address of Zoo token contract.
	/// @param _dai - address of DAI token contract.
	/// @param _vault - address of yearn.
	/// @param _zooGovernance - address of ZooDao Governance contract.
	constructor (address _zoo, address _dai, address _vault, address _zooGovernance) Ownable() ERC721("ZooBattle", "ZooB")
	{
		zoo = ERC20(_zoo);
		dai = ERC20(_dai);
		vault = VaultAPI(_vault);
		zooGovernance = ZooGovernance(_zooGovernance);
		zooFunctions = IZooFunctions(zooGovernance.zooFunctions());

		epochStartDate = block.timestamp;//todo:change time for prod +  14 days;                              // Start date of 1st battle.
	}

	/// @notice Function to get info about nft pair in epoch for index.
	/// @param epoch - epoch number.
	/// @param i - index of nft pair
	function getNftPairInEpoch(uint256 epoch, uint256 i) public view returns (NftPair memory)
	{
		return pairsInEpoch[epoch][i];
	}

	function getNfts(uint256 i) public view returns (uint256 id)
	{
		return nfts[i];
	}

	/// @notice Function to get info about nfts in epoch for index.
	/// @param epoch - epoch number.
	/// @param i - index of nft.
	function getNftsInEpoch(uint256 epoch, uint256 i) public view returns (uint256 id)
	{
		return nftsInEpoch[epoch][i];
	}

	function getNftPairLenght(uint256 epoch) public view returns(uint256 length) {
		return pairsInEpoch[epoch].length;
	}

	function getNftsLenght(uint256 epoch) public view returns(uint256 length) {
		return nftsInEpoch[epoch].length;
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
		allowedForStaking[token] = true;                                   // Boolean for contract to be allowed for staking.

		emit newContractAllowed(token);
	}

	/// @notice Function for staking NFT in this pool.
	/// @param token - address of Nft token to stake
	/// @param id - id of nft token
	function stakeNft(address token, uint256 id) public
	{
		require(allowedForStaking[token] == true, "Nft not allowed!");             // Requires for nft-token to be from allowed contract.
		// Not need that require, because transferFrom already throws in that case.
		// require(tokenStakedBy[token][id] == address(0), "Already staked!");       // Requires for token to be non-staked before.
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!");  // Requires to be at first stage in battle epoch.

		IERC721(token).transferFrom(msg.sender, address(this), id);               // Sends NFT token to this contract.

		_safeMint(msg.sender, numberOfPositions);                       // Wraps in ZooBattle nft.

		positions[numberOfPositions] = PositionType.StakerPostion;      // Records type of position.
		stakingPositions[numberOfPositions].startEpoch = currentEpoch;  // Records startEpoch.
		stakingPositions[numberOfPositions].lastRewardedEpoch = currentEpoch;
		stakingPositions[numberOfPositions].token = token;              // Records nft contract address.
		stakingPositions[numberOfPositions].id = id;                    // Records id of nft.

		emit StakedNft(msg.sender, token, id, numberOfPositions);                                    // Emits StakedNft event.

		nfts.push(numberOfPositions);
		totalNftsInEpoch++;   // Increments amount of total nft in epoch.
		numberOfPositions++;  // Increments amount of positions.
	}

	function unstakeNft(uint256 positionId) public
	{
		require(positions[positionId] == PositionType.StakerPostion);
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!");  // Requires to be at first stage in battle epoch.
		require(ownerOf(positionId) == msg.sender);
		require(stakingPositions[positionId].endEpoch == 0);

		address token = stakingPositions[positionId].token;
		uint256 id = stakingPositions[positionId].id;

		stakingPositions[positionId].endEpoch = currentEpoch;

		IERC721(token).transferFrom(address(this), msg.sender, id);               // Transfers token back to owner.

		totalNftsInEpoch--;  // Decrements amount of total nft in epoch.

		for(uint i = 0; i < nfts.length; i++)
		{
			if (nfts[i] == positionId)
			{
				nfts[i] == nfts[nfts.length - 1];
				nfts.pop();
				break;
			}
		}

		emit WithdrawedNft(msg.sender, token, id);                                // Emits withdrawedNft event.
	}

	function claimRewardFromStaking(uint256 positionId, address beneficiary) public
	{
		require(positions[positionId] == PositionType.StakerPostion, "error");
		require(getCurrentStage() == Stage.FirstStage, "Must be at 1st stage!");  // Requires to be at first stage in battle epoch.
		require(ownerOf(positionId) == msg.sender, "error");

		uint endEpoch = stakingPositions[positionId].endEpoch;
		uint end = endEpoch == 0 ? currentEpoch : endEpoch;
		
		int256 yTokensReward = 0;

		for (uint256 i = stakingPositions[positionId].lastRewardedEpoch; i < end; i++)
		{
			int256 saldo = stakingPositions[positionId].rewards[i].yTokensSaldo;
			
			if (saldo > 0)
			{
				yTokensReward += saldo * 2 / 100;
			}
		}

		stakingPositions[positionId].lastRewardedEpoch = end;
		vault.withdraw(uint256(yTokensReward), beneficiary);
	}

	/// @notice Function for vote for nft in battle.
	/// @param positionId - id of staker position.
	/// @param amount - amount of dai to vote.
	/// @return votes - computed amount of votes.
	function createNewVotingPosition(uint256 positionId, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.SecondStage, "Must be at 2nd stage!");   // Requires to be at second stage of battle epoch.
		require(stakingPositions[positionId].endEpoch == 0, "Must be staked!");
		dai.transferFrom(msg.sender, address(this), amount);                        // Transfers DAI to this contract for vote.

		votes = zooFunctions.computeVotesByDai(amount);                             // Calculates amount of votes.

		dai.approve(address(vault), amount);                                        // Approves Dai for address of yearn vault for amount
		uint256 yTokensNumber = vault.deposit(amount);                              // deposits to yearn vault and record yTokens.

		_safeMint(msg.sender, numberOfPositions);

		positions[numberOfPositions] = PositionType.StakerPostion;
		votingPositions[numberOfPositions].startEpoch = currentEpoch;
		votingPositions[numberOfPositions].lastRewardedEpoch = currentEpoch;
		votingPositions[numberOfPositions].startDate = block.timestamp;
		votingPositions[numberOfPositions].yTokensNumber = yTokensNumber;
		votingPositions[numberOfPositions].stakingPositionId = positionId;

		votingPositions[numberOfPositions].daiInvested = amount; // Records amount of dai invested.
		votingPositions[numberOfPositions].daiVotes = votes;     // Records amount of votes computed from dai.

		votingPositions[numberOfPositions].votes = votes;        // Records amount of votes.

		stakingPositions[numberOfPositions].rewards[currentEpoch].votes += votes;

		numberOfPositions++;

		return votes;
	}

	function swap(uint i, uint j) internal
	{
		uint x = nfts[j];
		nfts[j] = nfts[i];
		nfts[i] = x;
		nftsInGame++;
	}

	function pairNft(uint stakingPositionId) external
	{
		require(getCurrentStage() == Stage.ThirdStage || getCurrentStage() == Stage.FourthStage, "Must be at 3rd or 4th stage!");          // Requires to be at 3rd stage of battle epoch.
		require(nfts.length / 2 < nftsInGame / 2);
		uint index1;

		for (uint i = 0; i < nfts.length; i++)
		{
			if (nfts[i] == stakingPositionId)
			{
				if (i < nftsInGame)
				{
					return;
				}
				else
				{
					index1 = i;
				}
			}
		}

		swap(nftsInGame, index1);

		uint256 random = uint256(keccak256(abi.encodePacked(uint256(blockhash(block.number - 1))))) % (nfts.length - nftsInGame);
		uint index2 = random + nftsInGame;
		uint position = nfts[index2];
		pairsInEpoch[currentEpoch].push(NftPair(stakingPositionId, position, false, false));

		stakingPositions[stakingPositionId].rewards[currentEpoch].tokensAtBattleStart = sharesToTokens(stakingPositions[stakingPositionId].rewards[currentEpoch].yTokens);
		stakingPositions[position].rewards[currentEpoch].tokensAtBattleStart = sharesToTokens(stakingPositions[position].rewards[currentEpoch].yTokens);

		swap(nftsInGame, index2);
	}

	/// @notice Function for boost\multiply votes with Zoo.
	/// @param amount - amount of Zoo.
	function voteWithZoo(uint256 stakingPositionId, uint256 votingPositionId, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.ThirdStage, "Must be at 3rd stage!");      // Requires to be at 3rd stage.
		//require(tokenStakedBy[token][id] != address(0), "Must be staked!");           // Requires to vote for staked nft.
		require(stakingPositions[stakingPositionId].endEpoch == 0, "Must be staked!");
		require(votingPositions[votingPositionId].endEpoch == 0, "error");

		zoo.transferFrom(msg.sender, address(this), amount);                          // Transfers Zoo from sender to this contract.

		votes = zooFunctions.computeVotesByZoo(amount);                               // Calculates amount of votes.

		require(votes <= votingPositions[votingPositionId].daiVotes, "votes amount more than invested!"); // Reverts if votes more than tokens invested.

		stakingPositions[stakingPositionId].rewards[currentEpoch].votes += votes;                   // Adds votes for this epoch, token and id.

		votingPositions[votingPositionId].votes += votes;         // Adds votes for this epoch, token and id for msg.sender.
		votingPositions[votingPositionId].zooInvested += amount;  // Adds amount of Zoo for this epoch, token and id for msg.sender.

		zooInEpochDeposited[currentEpoch] += amount;                                  // Adds amount of zoo deposited in current epoch.

		emit VotedWithZoo(msg.sender, stakingPositionId, amount);                             // Records in VotedWithZoo event.

		return votes;
	}

	function tokensToShares(int256 tokens) public view returns (int256)
	{
		return int256(uint256(tokens).mul(10 ** dai.decimals()).div(vault.pricePerShare()));
	}

	/// @notice Function for chosing winner for exact pair of nft.
	/// @param i - index of nft pair.
	/// @dev random should be changed for chainlink VRF. TODO:
	function chooseWinnerInPair(uint256 i) public
	{
		require(truncateAndPaired[currentEpoch] == true, "Must be paired before choosing!");
		require(pairsInEpoch[currentEpoch][i].playedInEpoch != true, "winner already chosen!"); // Requires to be called only once for pair in epoch.
		require(getCurrentStage() == Stage.FourthStage, "Must be at 4th stage!");    // Requires to be at 4th stage.

		uint256 random = zooFunctions.getRandomNumber(i);                        // Get random number.
		uint256 token1 = pairsInEpoch[currentEpoch][i].token1;                   // Address of 1st candidate.

		uint256 votesForA = stakingPositions[token1].rewards[currentEpoch].votes; // Votes for 1st candidate.
		
		uint256 token2 = pairsInEpoch[currentEpoch][i].token2;                   // Address of 2nd candidate.

		uint256 votesForB = stakingPositions[token2].rewards[currentEpoch].votes; // Votes for 2nd candidate.

		pairsInEpoch[currentEpoch][i].win = zooFunctions.decideWins(votesForA, votesForB, random); // Calculates winner and records it.
		// Вычислить доход за батл.
		// Пересчитать его не в dai, а в yTokens.
		// Записать в сальдо без снятий.
		uint256 tokensAtBattleEnd1 = sharesToTokens(stakingPositions[token1].rewards[currentEpoch].yTokens); // Amount of yTokens for token1 staking Nft position.
		uint256 tokensAtBattleEnd2 = sharesToTokens(stakingPositions[token2].rewards[currentEpoch].yTokens); // Amount of yTokens for token2 staking Nft position.
		
		int256 income = int256((tokensAtBattleEnd1.add(tokensAtBattleEnd2)).sub(stakingPositions[token1].rewards[currentEpoch].tokensAtBattleStart).sub(stakingPositions[token2].rewards[currentEpoch].tokensAtBattleStart)); // Calculates income.
		int256 yTokens = tokensToShares(income);

		if (pairsInEpoch[currentEpoch][i].win)                                     // If 1st candidate wins.
		{
			stakingPositions[token1].rewards[currentEpoch].yTokensSaldo += yTokens; // Records income to token1 saldo.
			stakingPositions[token2].rewards[currentEpoch].yTokensSaldo -= yTokens; // Subtract income from token2 saldo.

			stakingPositions[token1].rewards[currentEpoch + 1].yTokens = stakingPositions[token1].rewards[currentEpoch].yTokens + uint256(yTokens);
			stakingPositions[token2].rewards[currentEpoch + 1].yTokens = stakingPositions[token2].rewards[currentEpoch].yTokens - uint256(yTokens);

		}
		else                                                                       // If 2nd candidate wins.
		{
			stakingPositions[token1].rewards[currentEpoch].yTokensSaldo -= yTokens; // Subtract income from token1 saldo.
			stakingPositions[token2].rewards[currentEpoch].yTokensSaldo += yTokens; // Records income to token2 saldo.
			stakingPositions[token1].rewards[currentEpoch + 1].yTokens = stakingPositions[token1].rewards[currentEpoch].yTokens - uint256(yTokens);
			stakingPositions[token2].rewards[currentEpoch + 1].yTokens = stakingPositions[token2].rewards[currentEpoch].yTokens + uint256(yTokens);
		}

		numberOfPlayedPairsInEpoch[currentEpoch]++;                                // Increments amount of pairs played this epoch.
		pairsInEpoch[currentEpoch][i].playedInEpoch = true;                        // Records that this pair already played this epoch.

		emit Winner(currentEpoch, i, random);                                      // Emits Winner event.

		if (numberOfPlayedPairsInEpoch[currentEpoch] == pairsInEpoch[currentEpoch].length)
		{
			updateEpoch();  // calls updateEpoch if winner determined in every pair.
		}
	}

	/// @notice Function to increment epoch.
	function updateEpoch() public {
		require(getCurrentStage() == Stage.FourthStage, "Must be at 4th stage!"); // Requires fourth stage.
		require(block.timestamp >= epochStartDate + epochDuration || numberOfPlayedPairsInEpoch[currentEpoch] == pairsInEpoch[currentEpoch].length, "error msg"); // Requires fourth stage to end, or determine every pair winner.
		epochStartDate = block.timestamp;                              // Sets start of new epoch.
		currentEpoch++;                                                // Increments currentEpoch.
		nftsInGame = 0;
	}

	/// @notice Function to liquidate voting position and get the reward.
	/// @param positionId - id of position.
	/// @param beneficiary - address recipient.
	function liquidateVotingPosition(uint256 positionId, address beneficiary) public
	{
		require(votingPositions[positionId].endEpoch != 0, "error"); // Requires to be not liquidated yet.
		require(getCurrentStage() == Stage.FirstStage, "Must be at first stage!");// Requires to be at first stage.
		require(ownerOf(positionId) == msg.sender, "You're not an owner"); // Requires to be owner of position.

		zoo.transfer(beneficiary, votingPositions[positionId].zooInvested);// Transfers zoo to beneficiary.

		votingPositions[positionId].endDate = block.timestamp; // Sets endDate to now.
		votingPositions[positionId].endEpoch = currentEpoch;   // Sets endEpoch to currentEpoch.

		numberOfPositions--;
	}

	function claimRewardFromVoting(uint256 positionId, address beneficiary) public
	{
		require(getCurrentStage() == Stage.FirstStage, "Must be at first stage!");// Requires to be at first stage.
		require(ownerOf(positionId) == msg.sender, "You're not an owner"); // Requires to be owner of position.

		uint256 stakingPositionId = votingPositions[positionId].stakingPositionId;
		uint256 lastEpochOfStaking = stakingPositions[stakingPositionId].endEpoch;
		uint256 lastEpochNumber;
		
		if (lastEpochOfStaking != 0 && votingPositions[positionId].endEpoch != 0)
		{
			lastEpochNumber = Math.min(lastEpochOfStaking, votingPositions[positionId].endEpoch);
		}
		else if (lastEpochOfStaking != 0)
		{
			lastEpochNumber = lastEpochOfStaking;
		}
		else if (votingPositions[positionId].endEpoch != 0)
		{
			lastEpochNumber = votingPositions[positionId].endEpoch;
		}
		else
		{
			lastEpochNumber == currentEpoch;
		}

		int256 yTokens = int256(votingPositions[positionId].yTokensNumber); // Get yTokens from position.
		int256 votes = int256(votingPositions[positionId].votes);           // Get votes from position.

		for (uint i = votingPositions[positionId].lastRewardedEpoch; i < lastEpochNumber; i++)
		{
			int256 saldo = stakingPositions[stakingPositionId].rewards[i].yTokensSaldo;
			int256 totalVotes = int256(stakingPositions[stakingPositionId].rewards[i].votes);

			if (saldo > 0)
			{
				saldo * saldo * 98 / 100;
			}

			yTokens += saldo * votes / totalVotes;
		}

		vault.withdraw(uint256(yTokens), beneficiary);
		stakingPositions[stakingPositionId].rewards[currentEpoch].votes -= uint256(votes);     // Subtracts votes for this position.
		stakingPositions[stakingPositionId].rewards[currentEpoch].yTokens -= uint256(yTokens); // Subtracts yTokens for this position.

		votingPositions[positionId].lastRewardedEpoch = lastEpochNumber;
	}

	/// @notice Function calculate amount of shares.
	/// @param _sharesAmount - amount of shares.
	/// @return shares - calculated amount of shares.
	function sharesToTokens(uint256 _sharesAmount) public view returns (uint256 shares) ///todo:make internal // не надо, public для фронта
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
	/*
	function prepareForParing(uint256 stakingPositionId) external
	{
		uint256 i;
		uint256 length = nftsInEpoch[currentEpoch].length;

		for (i = 0; i < length; i++)
		{
			if (nftsInEpoch[currentEpoch][i] == stakingPositionId)
			{
				return;
			}
		}

		nftsInEpoch[currentEpoch].push(stakingPositionId);
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
			uint256 token1 = nftsInEpoch[currentEpoch][random1]; // Pick random nft contract address.

			nftsInEpoch[currentEpoch][random1] = nftsInEpoch[currentEpoch][length - 1];
			nftsInEpoch[currentEpoch].pop();                           // Remove from array.

			length = nftsInEpoch[currentEpoch].length;

			uint256 random2 = uint256(keccak256(abi.encodePacked(uint256(blockhash(block.number - 1)) + i++))) % length; // Generate 2nd random number.
			uint256 token2 = nftsInEpoch[currentEpoch][random2]; // Pick random nft contract address.

			nftsInEpoch[currentEpoch][random2] = nftsInEpoch[currentEpoch][length - 1];
			nftsInEpoch[currentEpoch].pop();                           // Remove from array.
			
			pairsInEpoch[currentEpoch].push(NftPair(token1,token2, false, false));  // Push pair.
		}

		return true;
	}
*/
/*ТЕПЕРЬ НЕ НУЖНО, тк награда реинвестируется и забирается в момент ликвидации позиции.
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
		require(investedInVoting[epoch][token][id][msg.sender].daiHaveWithdrawed != true, "Dai tokens were withdrawed!"); // Requires for tokens to be not withdrawed or reVoted yet.

		dai.transfer(msg.sender, investedInVoting[epoch][token][id][msg.sender].daiInvested); // Transfers dai.

		investedInVoting[epoch][token][id][msg.sender].daiHaveWithdrawed = true;              // Records that tokens were reVoted.

		emit WithdrawedDai(msg.sender, epoch, token, id, investedInVoting[epoch][token][id][msg.sender].daiInvested);                                     // Records in WithdrawedDai event.
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

	/// @notice Function for voting with DAI in battle epoch.
	/// @param token - address of Nft token voting for.
	/// @param id - id of voter.
	/// @param amount - amount of votes in DAI.
	/// @return votes - calculated amount of votes from dai for nft.
	function voteWithDai(address token, uint256 id, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.SecondStage, "Must be at 2nd stage!");   // Requires to be at second stage of battle epoch.
		require(stakingPositions[positionId].endEpoch == 0, "Must be staked!");
		dai.transferFrom(msg.sender, address(this), amount);                        // Transfers DAI to this contract for vote.

		votes = zooFunctions.computeVotesByDai(amount);                             // Calculates amount of votes.

		dai.approve(address(vault), amount);                                        // Approves Dai for address of yearn vault for amount
		uint256 yTokensNumber = vault.deposit(amount);                              // deposits to yearn vault and record yTokens.

		_safeMint(msg.sender, numberOfPositions);

		positions[numberOfPositions] = PositionType.StakerPostion;
		votingPositions[numberOfPositions].

		votesForNftInEpoch[currentEpoch][token][id].votes += votes;                 // Adds amount of votes for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].daiInvested += amount;          // Adds amount of Dai invested for this epoch, contract and id.
		votesForNftInEpoch[currentEpoch][token][id].yTokensNumber += yTokensNumber; // Adds amount of yTokens invested for this epoch, contract and id.

		//investedInVoting[currentEpoch][token][id][msg.sender].daiInvested += amount;// Adds amount of Dai invested for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][msg.sender].votes += votes;       // Adds amount of votes for this epoch, contract and id for msg.sender.
		//investedInVoting[currentEpoch][token][id][msg.sender].yTokensNumber += yTokensNumber;// Adds amount of yToken invested for this epoch, contract and id for msg.sender.

		uint256 length = nftsInEpoch[currentEpoch].length;                          // Sets amount of Nfts in current epoch.

		//daiInEpochDeposited[currentEpoch] += amount;                                // Adds amount of Dai deposited in current epoch.

		emit VotedWithDai(msg.sender, token, id, amount);                           // Records in VotedWithDai event.
		numberOfPositions++;

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
		//votesForNftInEpoch[currentEpoch][token][id].daiInvested += amount;          // Adds amount of Dai invested for this epoch, contract and id.
		//votesForNftInEpoch[currentEpoch][token][id].yTokensNumber += yTokensNumber; // Adds amount of yTokens invested for this epoch, contract and id.

		investedInVoting[currentEpoch][token][id][voter].daiInvested += amount;     // Adds amount of Dai invested for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][voter].votes += votes;            // Adds amount of votes for this epoch, contract and id for msg.sender.
		investedInVoting[currentEpoch][token][id][voter].yTokensNumber += yTokensNumber;// Adds amount of yToken invested for this epoch, contract and id for msg.sender.

		uint256 length = nftsInEpoch[currentEpoch].length;                          // Sets amount of Nfts in current epoch.

		//daiInEpochDeposited[currentEpoch] += amount;                                // Adds amount of Dai deposited in current epoch.

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
*/
}