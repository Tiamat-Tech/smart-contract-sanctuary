pragma solidity ^0.7.5;
pragma abicoder v2;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@chainlink/contracts/src/v0.7/VRFConsumerBase.sol";
import "./interfaces/IVault.sol";
// import {VaultAPI} from "../yearn-finance-vaults/contracts/BaseStrategy.sol";
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
	
	ERC20Burnable public zoo;                      // Zoo token interface.
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
		StakerPosition,
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

	/// @notice Struct for records about pairs of Nfts for battle.
	struct NftPair
	{
		uint256 token1;                // id of 1st candidate.
		uint256 token2;                // id of 2nd candidate.
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
	event StakedNft(address staker, address indexed token, uint256 indexed id, uint256 positionId, uint256 currentEpoch, uint256 indexed totalNfts);

	/// @notice Event records info about withdrawed nft from this pool.
	/// @param staker - address of nft staker.
	/// @param token - address of nft contract.
	/// @param id - id of staked nft.
	/// @param positionId - id of staker position.
	/// @param currentEpoch - number of current epoch.
	/// @param totalNfts - amount of staked nfts.
	event UnstakedNft(address staker, address indexed token, uint256 indexed id, uint256 positionId, uint256 currentEpoch, uint256 indexed totalNfts);

	/// @notice Event records info about created voting position.
	event CreatedVotingPosition(address voter, uint256 stakingPositionId, uint256 daiAmount, uint256 votes, uint256 votedForId);

	/// @notice Event records about vote using Zoo.
	/// @param voter - address voter.
	/// @param votingPositionId - id of staker position.
	/// @param votingPositionId - id of voting position.
	/// @param amount - amount of votes.
	event VotedWithZoo(address voter, uint256 indexed stakingPositionId, uint256 indexed votingPositionId, uint256 indexed amount);

	/// @notice Event records info about paired nfts.
	event NftPaired(uint256 fighter1, uint256 fighter2, uint256 currentVotesFor1, uint256 currentVotesFor2);

	/// @notice Event records info about winners in battles.
	/// @param currentEpoch - number of currentEpoch.
	/// @param i - index of battle.
	/// @param random - random number get for calculating winner.
	event Winner(uint256 currentEpoch, uint256 i, uint256 random, uint256 playedPairsAmount);

	/// @notice Event about liquidating voting position.
	event VotingPositionLiquidated(address indexed owner, address beneficiary, uint256 positionId, uint256 indexed zooReturned, uint256 indexed epoch);

	/// @notice Event records info about claimed reward from voting.
	event claimedRewardFromVoting(address indexed owner, address beneficiary, uint256 indexed reward, uint256 indexed positionId);

	/// @notice Event records info about claimed reward from staking.
	event claimedRewardFromStaking(address indexed owner, address beneficiary, uint256 indexed reward, uint256 positionId);
	
	// uint256 public totalNfts;                      // Amount of Nfts staked.

	uint256 public epochStartDate;                 // Start date of battle contract.
	uint256 public currentEpoch = 1;               // Counter for battle epochs.

	uint256 public firstStageDuration = 7 minutes;		//todo:change time //3 days;    // Duration of first stage.
	uint256 public secondStageDuration = 7 minutes;		//todo:change time//7 days;   // Duration of second stage.
	uint256 public thirdStageDuration = 7 minutes;		//todo:change time//5 days;    // Duration third stage.
	uint256 public fourthStage = 7 minutes;		//todo:change time//2 days;           // Duration of fourth stage.
	uint256 public epochDuration = firstStageDuration + secondStageDuration + thirdStageDuration + fourthStage; // Total duration of battle epoch.

	// Nft contract => allowed or not.
	mapping (address => bool) public allowedForStaking;                 // Records NFT contracts available for staking.

	// nft contract => nft id => address staker.
	// mapping (address => mapping (uint256 => address)) public tokenStakedBy; // Records that nft staked or not.

	// epoch number => amount of nfts.
	// mapping (uint256 => uint256[]) public nftsInEpoch;                      // Records amount of nft in battle epoch.

	// epoch number => amount of pairs of nfts.
	mapping (uint256 => NftPair[]) public pairsInEpoch;                 // Records amount of pairs in battle epoch.

	// epoch number => number of played pairs in epoch;
	mapping (uint256 => uint256) public numberOfPlayedPairsInEpoch;

	// epoch number => truncateAndPair called or not.
	// mapping (uint256 => bool) public paired;         // Records if participants were paired.

	// position id => positionType enum.
	mapping (uint256 => PositionType) public positions;                 // Records which type of position.

	// position id => StakerPosition struct.
	mapping (uint256 => StakerPosition) public stakingPositions;        // Records info about ZooBattle nft-position of staker.

	// position id => VotingPosition struct.
	mapping (uint256 => VotingPosition) public votingPositions;         // Records info about ZooBattle nft-position of voter.

	// address voter => array of voter positions.
	mapping (address => uint256[]) public positionsOfVoter;

	mapping (address => mapping (uint256 => address)) public tokenStakedBy;

	uint256 public numberOfPositions;                        // Id of ZooBattle nft.
	uint256[] public nfts;                                   // Array of ZooBattle nfts, which are stakerPositions.
	uint256 public nftsInGame;                               // paired nfts in battle.
	uint256 public numberOfNftsWithNonZeroVotes;
	uint256 public totalNfts;

	address public insurance; // Insurance pool.
	address public gasPool;    // Gas fee pool
	address public team;      // Team pool.

	/// @notice Contract constructor.
	/// @param _zoo - address of Zoo token contract.
	/// @param _dai - address of DAI token contract.
	/// @param _vault - address of yearn.
	/// @param _zooGovernance - address of ZooDao Governance contract.
	constructor (
		address _zoo, 
		address _dai, 
		address _vault, 
		address _zooGovernance, 
		address _insurancePool, 
		address _gasFeePool, 
		address _teamAddress
		) Ownable() ERC721("ZooBattle", "ZooB")
	{
		zoo = ERC20Burnable(_zoo);
		dai = ERC20(_dai);
		vault = VaultAPI(_vault);
		zooGovernance = ZooGovernance(_zooGovernance);
		zooFunctions = IZooFunctions(zooGovernance.zooFunctions());

		insurance = _insurancePool;
		gasPool = _gasFeePool;
		team = _teamAddress;

		epochStartDate = block.timestamp;//todo:change time for prod +  14 days;                              // Start date of 1st battle.
	}

	/// @notice Function for updating functions according last governance resolutions.
	function updateZooFunctions() external onlyOwner
	{
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!"); // Requires to be at first stage in battle epoch.

		zooFunctions = IZooFunctions(zooGovernance.zooFunctions());              // Sets ZooFunctions to contract specified in zooGovernance.
	}

	/// @notice Function to allow new NFT contract available for stacking.
	/// @param token - address of new Nft contract.
	function allowNewContractForStaking(address token) external onlyOwner
	{
		allowedForStaking[token] = true;                                   // Boolean for contract to be allowed for staking.

		emit newContractAllowed(token);
	}

	/// @notice Function to get info about nft pair in epoch for index.
	/// @param epoch - epoch number.
	/// @param i - index of nft pair
	function getNftPairInEpoch(uint256 epoch, uint256 i) public view returns (NftPair memory)
	{
		return pairsInEpoch[epoch][i];
	}

	/// @notice Function for getting amount of nft pairs in epoch.
	/// @param epoch - number of epoch.
	function getNftPairLenght(uint256 epoch) public view returns(uint256 length) {
		return pairsInEpoch[epoch].length;
	}

	/// @notice Function to get nft by index in array.
	/// @param i - index of id in array.
	/// @return id - id of zoo battles nft.
	function getNfts(uint256 i) public view returns (uint256 id)
	{
		return nfts[i];
	}

	/// @notice Function to get amount of nft in array nfts/staked in battles.
	/// @return amount - amount of ZooBattles nft.
	function getNftsLenght() public view returns (uint256 amount)
	{
		return nfts.length;
	}

	function getVotingPositions(address voter, uint256 i) public view returns (uint256 id) 
	{
		return positionsOfVoter[voter][i];
	}

	function getVotingPositionsLenght(address voter) public view returns(uint256 amount) {
		return positionsOfVoter[voter].length;
	}

	/// @notice Function to calculate amount of tokens from shares.
	/// @param _sharesAmount - amount of shares.
	/// @return tokens - calculated amount tokens from shares.
	function sharesToTokens(uint256 _sharesAmount) public view returns (uint256 tokens)
	{
		return _sharesAmount.mul(vault.pricePerShare()).div(10 ** dai.decimals());
	}
	/// @notice Function for calculating tokens to shares.
	/// @param tokens - amount of tokens to calculate.
	/// @return shares - calculated amount of shares.
	function tokensToShares(int256 tokens) public view returns (int256 shares)
	{
		return int256(uint256(tokens).mul(10 ** dai.decimals()).div(vault.pricePerShare()));
	}

	/// @notice Function for staking NFT in this pool.
	/// @param token - address of Nft token to stake
	/// @param id - id of nft token
	function stakeNft(address token, uint256 id) public
	{
		require(allowedForStaking[token] == true, "Nft not allowed!");            // Requires for nft-token to be from allowed contract.
		// Not need that require, because transferFrom already throws in that case.
		// require(tokenStakedBy[token][id] == address(0), "Already staked!");    // Requires for token to be non-staked before.
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!");  // Requires to be at first stage in battle epoch.

		IERC721(token).transferFrom(msg.sender, address(this), id);               // Sends NFT token to this contract.

		_safeMint(msg.sender, numberOfPositions);                       // Wraps in ZooBattle nft.

		positions[numberOfPositions] = PositionType.StakerPosition;     // Records type of position.
		stakingPositions[numberOfPositions].startEpoch = currentEpoch;  // Records startEpoch.
		stakingPositions[numberOfPositions].lastRewardedEpoch = currentEpoch;
		stakingPositions[numberOfPositions].token = token;              // Records nft contract address.
		stakingPositions[numberOfPositions].id = id;                    // Records id of nft.

		tokenStakedBy[token][id] = msg.sender;                          // Records address of staker.

		nfts.push(numberOfPositions);
		totalNfts++;   // Increments amount of total nft in battle arena.
		numberOfPositions++;  // Increments amount of positions.

		emit StakedNft(msg.sender, token, id, numberOfPositions, currentEpoch, totalNfts);     // Emits StakedNft event.

	}

	/// @notice Function for withdrawal staking nft.
	/// @param positionId - id of staker position.
	function unstakeNft(uint256 positionId) public
	{
		require(positions[positionId] == PositionType.StakerPosition, "Wrong position type");
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!");  // Requires to be at first stage in battle epoch.
		require(ownerOf(positionId) == msg.sender, "Not the owner!");
		// require(stakingPositions[positionId].endEpoch == 0, "already unstaked");

		address token = stakingPositions[positionId].token;
		uint256 id = stakingPositions[positionId].id;

		stakingPositions[positionId].endEpoch = currentEpoch;

		IERC721(token).transferFrom(address(this), msg.sender, id);               // Transfers token back to owner.

		tokenStakedBy[token][id] = address(0);                      // Changes address to zero.

		totalNfts--;  // Decrements amount of total nft in epoch.

		for(uint i = 0; i < nfts.length; i++)
		{
			if (nfts[i] == positionId)
			{
				nfts[i] = nfts[nfts.length - 1];
				nfts.pop();
				break;
			}
		}

		emit UnstakedNft(msg.sender, token, id, positionId, currentEpoch, totalNfts);      // Emits withdrawedNft event.
	}

	/// @notice Function to claim reward for staker.
	/// @param positionId - id of staker position.
	/// @param beneficiary - address of recipient.
	function claimRewardFromStaking(uint256 positionId, address beneficiary) public
	{
		require(positions[positionId] == PositionType.StakerPosition, "Wrong position type");
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!");  // Requires to be at first stage in battle epoch.
		require(ownerOf(positionId) == msg.sender, "Not the owner!");

		uint256 endEpoch = stakingPositions[positionId].endEpoch;
		uint256 end = endEpoch == 0 ? currentEpoch : endEpoch;
		
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

		// vault.transfer(uint256(yTokensReward), beneficiary);
		uint256 reward = vault.withdraw(sharesToTokens(uint256(yTokensReward)), beneficiary);

		dai.transfer(beneficiary, reward);

		emit claimedRewardFromStaking(msg.sender, beneficiary, reward, positionId);
	}

	/// @notice Function to get pending reward fo staker for this position id.
	/// @param positionId - id of staker position.
	/// @return stakerReward - reward amount for staker of this nft.
	function getPendingStakerReward(uint256 positionId) public view returns (uint256 stakerReward)
	{
		require(positions[positionId] == PositionType.StakerPosition, "Wrong position type");
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
		uint256 reward = sharesToTokens(uint256(yTokensReward));
		return reward;
	}

	/// @notice Function for vote for nft in battle.
	/// @param positionId - id of staker position.
	/// @param amount - amount of dai to vote.
	/// @return votes - computed amount of votes.
	function createNewVotingPosition(uint256 positionId, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.SecondStage, "Wrong stage!");   // Requires to be at second stage of battle epoch.
		require(_exists(positionId), "wrong position id");
		require(stakingPositions[positionId].startEpoch != 0, "not staked");
		dai.transferFrom(msg.sender, address(this), amount);                        // Transfers DAI to this contract for vote.

		votes = zooFunctions.computeVotesByDai(amount);                             // Calculates amount of votes.

		dai.approve(address(vault), amount);                                        // Approves Dai for address of yearn vault for amount
		uint256 yTokensNumber = vault.deposit(amount);                              // deposits to yearn vault and record yTokens.

		_safeMint(msg.sender, numberOfPositions);

		positions[numberOfPositions] = PositionType.VoterPosition;

		votingPositions[numberOfPositions].stakingPositionId = positionId;
		votingPositions[numberOfPositions].daiInvested = amount; // Records amount of dai invested.
		votingPositions[numberOfPositions].yTokensNumber = yTokensNumber; // Records amount of yTokens obtained from vault.
		votingPositions[numberOfPositions].daiVotes = votes;     // Records amount of votes computed from dai.
		votingPositions[numberOfPositions].votes = votes;        // Records amount of votes.

		votingPositions[numberOfPositions].startDate = block.timestamp;
		votingPositions[numberOfPositions].startEpoch = currentEpoch;
		votingPositions[numberOfPositions].lastRewardedEpoch = currentEpoch;

		if (stakingPositions[positionId].rewards[currentEpoch].votes == 0)
		{
			for(uint i = 0; i < nfts.length; i++)
			{
				if (nfts[i] == positionId)
				{
					// swap(numberOfNftsWithNonZeroVotes, positionId);
					(numberOfNftsWithNonZeroVotes, positionId) = (positionId, numberOfNftsWithNonZeroVotes);
					numberOfNftsWithNonZeroVotes++;
					break;
				}
			}
		}

		stakingPositions[positionId].rewards[currentEpoch].votes += votes;
		stakingPositions[positionId].rewards[currentEpoch].yTokens += yTokensNumber;

		positionsOfVoter[msg.sender].push(numberOfPositions); // Records id of position into array for voter address.

		numberOfPositions++;

		emit CreatedVotingPosition(msg.sender, positionId, amount, votes, numberOfPositions.sub(1));

		return votes;
	}

	// function swap(uint256 i, uint256 j) internal
	// {
	// 	uint256 x = nfts[j];
	// 	nfts[j] = nfts[i];
	// 	nfts[i] = x;
	// }

	/// @notice Function for pair nft for battles.
	/// @param stakingPositionId - id of staker position.
	function pairNft(uint256 stakingPositionId) external
	{
		require(getCurrentStage() == Stage.ThirdStage || getCurrentStage() == Stage.FourthStage, "Wrong stage!");  // Requires to be at 3stage of battle epoch.
		require(numberOfNftsWithNonZeroVotes / 2 > nftsInGame / 2, "there is no opponent"); // checks if there enough nft for pairing.
		require(_exists(stakingPositionId), "wrong position id"); // checks if this id exist in battles nft. todo: specify for staker type.
		uint256 index1;

		for (uint256 i = 0; i < nftsInGame; i++)
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

		// swap(nftsInGame, index1);
		(nftsInGame, index1) = (index1, nftsInGame);
		nftsInGame++;

		uint256 random = uint256(keccak256(abi.encodePacked(uint256(blockhash(block.number - 1))))) % (numberOfNftsWithNonZeroVotes - nftsInGame);
		uint256 index2 = random + nftsInGame;
		uint256 stakingPosition2 = nfts[index2];
		pairsInEpoch[currentEpoch].push(NftPair(stakingPositionId, stakingPosition2, false, false));

		stakingPositions[stakingPositionId].rewards[currentEpoch].tokensAtBattleStart = sharesToTokens(stakingPositions[stakingPositionId].rewards[currentEpoch].yTokens);
		stakingPositions[stakingPosition2].rewards[currentEpoch].tokensAtBattleStart = sharesToTokens(stakingPositions[stakingPosition2].rewards[currentEpoch].yTokens);

		// swap(nftsInGame, index2);
		(nftsInGame, index2) = (index2, nftsInGame);
		nftsInGame++;

		emit NftPaired(stakingPositionId, stakingPosition2, stakingPositions[stakingPositionId].rewards[currentEpoch].tokensAtBattleStart, stakingPositions[stakingPosition2].rewards[currentEpoch].tokensAtBattleStart);
	}

	/// @notice Function for boost\multiply votes with Zoo.
	/// @param stakingPositionId - id of staker position.
	/// @param votingPositionId - id of voter position.
	/// @param amount - amount of Zoo.
	function voteWithZoo(uint256 stakingPositionId, uint256 votingPositionId, uint256 amount) public returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.ThirdStage, "Wrong stage!");      // Requires to be at 3rd stage.
		//require(tokenStakedBy[token][id] != address(0), "Must be staked!");         // Requires to vote for staked nft.
		require(ownerOf(votingPositionId) == msg.sender, "wrong position id"); // Checks for existence and ownership of voting position.
		require(stakingPositions[stakingPositionId].endEpoch == 0, "Position liquidated");
		require(votingPositions[votingPositionId].endEpoch == 0, "Position liquidated");

		zoo.transferFrom(msg.sender, address(this), amount);                   // Transfers Zoo from sender to this contract.

		votes = zooFunctions.computeVotesByZoo(amount);                        // Calculates amount of votes.

		require(votes <= votingPositions[votingPositionId].daiVotes, "votes amount more than invested!"); // Reverts if votes more than tokens invested.

		stakingPositions[stakingPositionId].rewards[currentEpoch].votes += votes;  // Adds votes for this epoch, token and id.

		votingPositions[votingPositionId].votes += votes;                      // Adds votes for this epoch, token and id for msg.sender.
		votingPositions[votingPositionId].zooInvested += amount;               // Adds amount of Zoo for this epoch, token and id for msg.sender.

		emit VotedWithZoo(msg.sender, stakingPositionId, votingPositionId, amount);              // Records in VotedWithZoo event.

		return votes;
	}

	/// @notice Function for chosing winner for exact pair of nft.
	/// @param i - index of nft pair.
	/// @dev random should be changed for chainlink VRF. TODO:
	function chooseWinnerInPair(uint256 i) public
	{
		// require(paired[currentEpoch] == true, "Must be paired before choosing!");
		require(pairsInEpoch[currentEpoch][i].playedInEpoch != true, "winner already chosen!"); // Requires to be called only once for pair in epoch.
		require(getCurrentStage() == Stage.FourthStage, "Wrong stage!");    // Requires to be at 4th stage.

		uint256 random = zooFunctions.getRandomNumber(i);                         // Get random number.
		uint256 token1 = pairsInEpoch[currentEpoch][i].token1;                    // id of 1st candidate.
		updateInfo(token1);
		uint256 votesForA = stakingPositions[token1].rewards[currentEpoch].votes; // Votes for 1st candidate.
		
		uint256 token2 = pairsInEpoch[currentEpoch][i].token2;                    // id of 2nd candidate.
		updateInfo(token2);
		uint256 votesForB = stakingPositions[token2].rewards[currentEpoch].votes; // Votes for 2nd candidate.

		pairsInEpoch[currentEpoch][i].win = zooFunctions.decideWins(votesForA, votesForB, random); // Calculates winner and records it.

		uint256 tokensAtBattleEnd1 = sharesToTokens(stakingPositions[token1].rewards[currentEpoch].yTokens); // Amount of yTokens for token1 staking Nft position.
		uint256 tokensAtBattleEnd2 = sharesToTokens(stakingPositions[token2].rewards[currentEpoch].yTokens); // Amount of yTokens for token2 staking Nft position.
		
		int256 income = int256((tokensAtBattleEnd1.add(tokensAtBattleEnd2)).sub(stakingPositions[token1].rewards[currentEpoch].tokensAtBattleStart).sub(stakingPositions[token2].rewards[currentEpoch].tokensAtBattleStart)); // Calculates income.
		int256 yTokens = tokensToShares(income);

		if (pairsInEpoch[currentEpoch][i].win)                                      // If 1st candidate wins.
		{
			stakingPositions[token1].rewards[currentEpoch].yTokensSaldo += yTokens; // Records income to token1 saldo.
			stakingPositions[token2].rewards[currentEpoch].yTokensSaldo -= yTokens; // Subtract income from token2 saldo.

			stakingPositions[token1].rewards[currentEpoch + 1].yTokens = stakingPositions[token1].rewards[currentEpoch].yTokens + uint256(yTokens);
			stakingPositions[token2].rewards[currentEpoch + 1].yTokens = stakingPositions[token2].rewards[currentEpoch].yTokens - uint256(yTokens);

		}
		else                                                                        // If 2nd candidate wins.
		{
			stakingPositions[token1].rewards[currentEpoch].yTokensSaldo -= yTokens; // Subtract income from token1 saldo.
			stakingPositions[token2].rewards[currentEpoch].yTokensSaldo += yTokens; // Records income to token2 saldo.
			stakingPositions[token1].rewards[currentEpoch + 1].yTokens = stakingPositions[token1].rewards[currentEpoch].yTokens - uint256(yTokens);
			stakingPositions[token2].rewards[currentEpoch + 1].yTokens = stakingPositions[token2].rewards[currentEpoch].yTokens + uint256(yTokens);
		}

		numberOfPlayedPairsInEpoch[currentEpoch]++;                                // Increments amount of pairs played this epoch.
		pairsInEpoch[currentEpoch][i].playedInEpoch = true;                        // Records that this pair already played this epoch.

		emit Winner(currentEpoch, i, random, numberOfPlayedPairsInEpoch[currentEpoch]); // Emits Winner event.

		if (numberOfPlayedPairsInEpoch[currentEpoch] == pairsInEpoch[currentEpoch].length)
		{
			updateEpoch();  // calls updateEpoch if winner determined in every pair.
		}
	}

	/// @dev Function for updating position in case of battle didn't happen after pairing.
	function updateInfo(uint256 positionId) internal returns (uint256)
	{
		uint256 end = stakingPositions[positionId].startEpoch;
		bool votesHasUpdated = false;
		bool yTokensHasUpdated = false;

		for (uint256 i = currentEpoch; i >= end; i--)
		{
			if (!votesHasUpdated && stakingPositions[positionId].rewards[i].votes != 0)
			{
				stakingPositions[positionId].rewards[currentEpoch].votes = stakingPositions[positionId].rewards[i].votes;
				votesHasUpdated = true;
			}

			if (!yTokensHasUpdated && stakingPositions[positionId].rewards[i].yTokens != 0)
			{
				stakingPositions[positionId].rewards[currentEpoch].yTokens = stakingPositions[positionId].rewards[i].yTokens;
				yTokensHasUpdated = true;
			}
			
			if (votesHasUpdated && yTokensHasUpdated)
			{
				break;
			}
		}
	}

	/// @notice Function to increment epoch.
	function updateEpoch() public {
		require(getCurrentStage() == Stage.FourthStage, "Wrong stage!"); // Requires fourth stage.
		require(block.timestamp >= epochStartDate + epochDuration || numberOfPlayedPairsInEpoch[currentEpoch] == pairsInEpoch[currentEpoch].length, "error msg"); // Requires fourth stage to end, or determine every pair winner.
		epochStartDate = block.timestamp;                              // Sets start of new epoch.
		currentEpoch++;                                                // Increments currentEpoch.
		nftsInGame = 0;
	}

	/// @notice Function to liquidate voting position and claim reward.
	/// @param positionId - id of position.
	/// @param beneficiary - address of recipient.
	function liquidateVotingPosition(uint256 positionId, address beneficiary) public
	{
		require(votingPositions[positionId].endEpoch != 0, "liquidate error"); // Requires to be not liquidated yet.
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!");// Requires to be at first stage.
		require(ownerOf(positionId) == msg.sender, "Not the owner!"); // Requires to be owner of position.

		uint256 zooReturned = votingPositions[positionId].zooInvested * 995 / 1000;
		uint256 zooToBurn = votingPositions[positionId].zooInvested * 5 / 1000;

		zoo.transfer(beneficiary, zooReturned);// Transfers zoo to beneficiary.

		zoo.burn(zooToBurn); // 0.5% burn.

		votingPositions[positionId].endDate = block.timestamp; // Sets endDate to now.
		votingPositions[positionId].endEpoch = currentEpoch;   // Sets endEpoch to currentEpoch.

		for(uint256 i = 0; i < positionsOfVoter[msg.sender].length; i++)
		{
			if (positionsOfVoter[msg.sender][i] == positionId)
			{
				positionsOfVoter[msg.sender][i] = positionsOfVoter[msg.sender][positionsOfVoter[msg.sender].length - 1];
				positionsOfVoter[msg.sender].pop();
				break;
			}
		}

		uint256 stakingPositionId = votingPositions[positionId].stakingPositionId;
		if (stakingPositions[stakingPositionId].rewards[currentEpoch].votes == 0)
		{
			for(uint256 i = 0; i < nfts.length; i++)
			{
				if (nfts[i] == stakingPositionId)
				{
					// swap(numberOfNftsWithNonZeroVotes - 1, stakingPositionId);
					(numberOfNftsWithNonZeroVotes, stakingPositionId) = (stakingPositionId, numberOfNftsWithNonZeroVotes);
					numberOfNftsWithNonZeroVotes--;
					break;
				}
			}
		}

		numberOfPositions--;

		emit VotingPositionLiquidated (msg.sender, beneficiary, positionId, votingPositions[positionId].zooInvested, currentEpoch);
	}

	/// @notice Function to claim reward in yTokens from voting.
	/// @param positionId - id of voting position.
	/// @param beneficiary - address of recipient.
	function claimRewardFromVoting(uint256 positionId, address beneficiary) public
	{
		require(getCurrentStage() == Stage.FirstStage, "Wrong stage!");// Requires to be at first stage.
		require(ownerOf(positionId) == msg.sender, "Not the owner!"); // Requires to be owner of position.

		uint256 stakingPositionId = votingPositions[positionId].stakingPositionId;
		(uint256 yTokens, uint256 yTokensIns, uint256 yTokensGas, uint256 yTokensTeam, uint256 lastEpochNumber) = getPendingVoterReward(positionId);

		uint256 reward = vault.withdraw(uint256(yTokens), beneficiary);

		uint256 insFee = vault.withdraw(yTokensIns, address(this));
		uint256 gasPoolFee = vault.withdraw(yTokensGas, address(this));
		uint256 teamFee = vault.withdraw(yTokensTeam, address(this));

		stakingPositions[stakingPositionId].rewards[currentEpoch].yTokens -= uint256(yTokens + yTokensIns + yTokensGas + yTokensTeam); // Subtracts yTokens for this position.

		votingPositions[positionId].lastRewardedEpoch = lastEpochNumber;

		dai.transfer(beneficiary, reward);

		dai.transfer(insurance, insFee);
		dai.transfer(gasPool, gasPoolFee);
		dai.transfer(team, teamFee);

		emit claimedRewardFromVoting(msg.sender, beneficiary, reward, positionId);
	}

	/// @notice Function to get pending reward from voting for position with this id.
	/// @param positionId - id of staking position in battles.
	/// @return rewardAmount - amount of pending reward.
	function getPendingVoterReward(uint256 positionId) public view returns (uint256 rewardAmount, uint256 rewardIns, uint256 rewardGas, uint256 rewardTeam, uint256 lastEpochNumber)
	{
		uint256 stakingPositionId = votingPositions[positionId].stakingPositionId;
		uint256 lastEpochOfStaking = stakingPositions[stakingPositionId].endEpoch;
		// uint256 lastEpochNumber;
		
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
			lastEpochNumber = currentEpoch;
		}

		int256 yTokens = int256(votingPositions[positionId].yTokensNumber); // Get yTokens from position.
		int256 votes = int256(votingPositions[positionId].votes);           // Get votes from position.

		int256 yTokensIns;
		int256 yTokensGas;
		int256 yTokensTeam;

		for (uint i = votingPositions[positionId].lastRewardedEpoch; i < lastEpochNumber; i++)
		{
			int256 saldo = stakingPositions[stakingPositionId].rewards[i].yTokensSaldo;
			int256 totalVotes = int256(stakingPositions[stakingPositionId].rewards[i].votes);

			if (saldo > 0)
			{
				yTokensIns += (saldo * 2 / 100) * votes / totalVotes;
				yTokensGas += (saldo * 1 / 100) * votes / totalVotes;
				yTokensTeam += (saldo * 1 / 100) * votes / totalVotes;

				saldo = saldo * 94 / 100; // 94 for voter, 2 1 1 for fee, 2 for staker.
			}

			yTokens += saldo * votes / totalVotes;
		}
		rewardAmount = sharesToTokens(uint256(yTokens));

		rewardIns = sharesToTokens(uint256(yTokensIns));
		rewardGas = sharesToTokens(uint256(yTokensGas));
		rewardTeam = sharesToTokens(uint256(yTokensTeam));
	}

	/// @notice Function to recompute votes from dai.
	/// @param votingPositionId - id of voting position.
	function recomputeDaiVotes(uint256 votingPositionId) external
	{
		require(getCurrentStage() == Stage.SecondStage, "Wrong stage!");   // Requires to be at second stage of battle epoch.
		// require(getPendingVoterReward(votingPositionId) == 0, "Reward must be claimed");

		uint256 daiNumber = votingPositions[votingPositionId].daiInvested;
		uint256 newVotes = zooFunctions.computeVotesByDai(daiNumber);
		uint256 votes = votingPositions[votingPositionId].votes;

		require(newVotes > votingPositions[votingPositionId].votes, "recomputed to lower value");

		votingPositions[votingPositionId].daiVotes = newVotes;
		votingPositions[votingPositionId].votes = newVotes;

		stakingPositions[votingPositionId].rewards[currentEpoch].votes += newVotes - votes;
		// TODO: добавить проверки на активность позиции голосующего и соотвествующую её позицию стейкера
	}

	/// @notice Function to recompute votes from zoo.
	/// @param votingPositionId - id of voting position.
	function recomputeZooVotes(uint256 votingPositionId) external
	{
		require(getCurrentStage() == Stage.ThirdStage, "Wrong stage!");      // Requires to be at 3rd stage.
		// require(getPendingVoterReward(votingPositionId) == 0, "Reward must be claimed");
		// TODO: добавить проверки
		uint256 zooNumber = votingPositions[votingPositionId].zooInvested;
		uint256 newZooVotes = zooFunctions.computeVotesByZoo(zooNumber);

		require(newZooVotes > votingPositions[votingPositionId].votes.sub(votingPositions[votingPositionId].daiVotes), "recomputed to lower value");
		require(newZooVotes <= votingPositions[votingPositionId].daiVotes, "Must be <= of votes from");

		uint256 delta = newZooVotes.add(votingPositions[votingPositionId].daiVotes).sub(votingPositions[votingPositionId].votes);
		stakingPositions[votingPositionId].rewards[currentEpoch].votes += delta;
		votingPositions[votingPositionId].votes += delta;
	}

	/// @notice Function to add dai tokens to voting position.
	/// @param votingPositionId - id of voting position.
	/// @param amount - amount of dai tokens to add.
	function addDaiToPosition(uint256 votingPositionId, uint256 amount) external returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.SecondStage, "Wrong stage!");   // Requires to be at second stage of battle epoch.
		// require(getPendingVoterReward(votingPositionId) == 0, "Reward must be claimed");
		/// TODO: добавить проверки на активность позиции голосующего и соотвествующую её позицию стейкера

		dai.transferFrom(msg.sender, address(this), amount);
		votes = zooFunctions.computeVotesByDai(amount);
		dai.approve(address(vault), amount);
		uint256 yTokensNumber = vault.deposit(amount);

		votingPositions[votingPositionId].daiInvested += amount;
		votingPositions[votingPositionId].yTokensNumber += yTokensNumber;
		votingPositions[votingPositionId].daiVotes += votes;
		votingPositions[votingPositionId].votes += votes;

		uint256 positionId = votingPositions[votingPositionId].stakingPositionId;
		stakingPositions[positionId].rewards[currentEpoch].votes += votes;
		stakingPositions[positionId].rewards[currentEpoch].yTokens += yTokensNumber;
	}

	/// @notice Function to add zoo tokens to voting position.
	/// @param votingPositionId - id of voting position.
	/// @param amount - amount of zoo tokens to add.
	function addZooToPosition(uint256 votingPositionId, uint256 amount) external returns (uint256 votes)
	{
		require(getCurrentStage() == Stage.ThirdStage, "Wrong stage!");      // Requires to be at 3rd stage.
		// require(getPendingVoterReward(votingPositionId) == 0, "Reward must be claimed");
		/// TODO: добавить проверки на активность позиции голосующего и соотвествующую её позицию стейкера

		zoo.transferFrom(msg.sender, address(this), amount);
		votes = zooFunctions.computeVotesByZoo(amount);

		uint256 zooVotes = votingPositions[votingPositionId].votes - votingPositions[votingPositionId].daiVotes;
		require(zooVotes + votes <= votingPositions[votingPositionId].daiVotes, "votes amount more than invested!"); // Reverts if votes more than tokens invested.

		uint256 stakingPositionId = votingPositions[votingPositionId].stakingPositionId;
		stakingPositions[stakingPositionId].rewards[currentEpoch].votes += votes;
		votingPositions[votingPositionId].zooInvested += amount;
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