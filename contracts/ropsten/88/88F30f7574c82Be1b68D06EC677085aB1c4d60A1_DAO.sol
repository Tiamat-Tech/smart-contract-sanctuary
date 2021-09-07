pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "./ZooToken.sol";
import "./Multiownable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/// @title DAO contract for token distribution.
/// @notice Contains logics, numbers and dates of payout tokens for epochs in yieldFarm, and for team, investors and influencers.
contract DAO is Ownable, Multiownable
{
	using SafeMath for uint256;

	ZooToken public token;

	address public coreTeam;                                         // Address of core team.
	address public yieldFarm;                                        // Address of yieldFarm contract.

	uint256 public payoutToCoreTeamDate;                             // Date for payout to core team.

	uint256 CounterWithdrawToCoreTeam = 0;                           // Counter for payout to core team.
	uint256 NumberOfEpochsLeft = 144;                                // Counter for epochs with provided reward left.

	uint256 public totalToCoreTeam = 10 ** 8 * 10 ** 18 * 12 / 100;  // Total amount of payout to core team - 12% of 100 mln ZOO.
	uint256 public rewardVault = 10 ** 8 * 10 ** 18 * 144 / 1000;    // Total amount of tokens for epochs in yieldFarm - 14.4% of 100 mln ZOO.
	uint256 public rewardVaultEpochB = 10 ** 8 * 10 ** 18 * 8 / 100; // Total amount of tokens for epochB - reward for nft staking, currently 8 mln zoo.
	uint256 public rewardVaultEpochC = 10 ** 8 * 10 ** 18 * 12 / 100;// Total amount of tokens for epochC - reward for voting, currently 12 mln Zoo.

	uint256 public rewardVaultEpochD = 10 ** 8 * 10 ** 18 * 25 / 1000;// Total amount of tokens for epochD - vault for gas compensation, currently 2.5 mln Zoo.

	uint256 public totalForPrivateInvestors = 10 ** 8 * 10 ** 18 * 9 / 100;// Total amount of payout to investors - 9% of 100 mln ZOO.
	uint256 public distributedBetweenPrivateInvestors = 0;            // Counter of payout for investors.
	uint256 public dateOfPrivateInvestorRelease;                      // Date of payout for investors.

	uint256 public dateOfReward;                                      // Date of reward from epochs in yieldFarm staking pool.

	mapping (address => uint256) public privateInvestorsBalances;     // Mapping for investors balances.

	/// @notice Contract constructor, sets the start date of yieldFarm staking pool and dates of payouts.
	/// @param _token - Address of Zoo token.
	/// @param _coreTeam - Address of Zoo devs core team wallet.
	/// @param _yieldFarm - Address of Zoo yield farm contract.
	constructor (address _token, address _coreTeam, address _yieldFarm) Ownable()
	{
		token = ZooToken(_token);
		payoutToCoreTeamDate = block.timestamp + 1 minutes;//182 days;         // Payout date for core Team.
		dateOfReward = block.timestamp + 1 minutes;//7 days;                   // Payout date for epoch in yieldFarm staking pool.
		dateOfPrivateInvestorRelease = block.timestamp + 1 minutes;//182 days; // Payout date for investors.
		coreTeam = _coreTeam;
		yieldFarm = _yieldFarm;
	}

	/// @notice Function for payout to devs core team.
	function withdrawToCoreTeam() external
	{
		require (block.timestamp >= payoutToCoreTeamDate, "Not the date of payout yet");// Requires date of payout.
		require (CounterWithdrawToCoreTeam <= 100); //10);                              // Limits the payouts for 10 times.
		token.transfer(coreTeam, totalToCoreTeam * 10 / 100);                           // Transfers payout for 10% of total amount weekly.
		CounterWithdrawToCoreTeam += 1;                                                 // Counter of payouts already done.
		payoutToCoreTeamDate += 1 minutes; //7 days;                                    // Sets next payout date to the next week.
	}

	/// @notice Function for withdrawal tokens from this contract to staking pool.
	/// @notice Could be called once a week, in terms to refill current epoch reward in yieldFarm staking pool.
	function withdrawToYieldFarm() external
	{
		require(block.timestamp >= dateOfReward, "Not the Date of Reward yet");  // Requires date of reward.
		uint256 rewardValue = rewardVault.div(NumberOfEpochsLeft);               // Calculates epoch reward value.
		token.transfer(yieldFarm, rewardValue);                                  // Transfers reward value to epoch in yieldFarm staking pool.
		dateOfReward += 1 minutes; //7 days;                                     // Sets next date of reward for next week.
		rewardVault = rewardVault.sub(rewardValue);                              // Decreases rewardVault for tokens transfered.
		if (NumberOfEpochsLeft > 1) {                                            // Decreases number of epochs left by one,
				NumberOfEpochsLeft -= 1;                                         // up to minimum of 1.
			}
	}

	/// @notice Function for adding share to investor.
	/// @param investor - address of investor.
	/// @param value - amount of share of tokens.
	function addPrivateInvestorShare(address investor, uint256 value) onlyOwner() external
	{
		require(distributedBetweenPrivateInvestors + value < totalForPrivateInvestors,
		 "Everything already distributed");                                   // Limits amount of tokens for investors.
		distributedBetweenPrivateInvestors += value;                          // Increases amount of tokens already distributed for investors.
		privateInvestorsBalances[investor] += value * 9 / 10;                 // Increases balances of payout of investor for 90% of his share.
		token.transfer(investor, value * 1 / 10);                             // Transfers 10% of his payout instantly.
	}

	/// @notice Function for withdrawing payout to investors.
	/// @param investor - address of investor.
	function withdrawToPrivateInvestor(address investor) external
	{
		require(block.timestamp > dateOfPrivateInvestorRelease);             // Requires date of payout.

		token.transfer(investor, privateInvestorsBalances[investor]);        // Transfers to investor his part of tokens.
	}

	uint256 public rewardVaultEpochE = 10 ** 8 * 10 ** 18 * 111 / 1000;      // Total amount of tokens for epochE - vault for future partnership rewards, currently 11.1 mln Zoo
	
	/// @notice Function for payout for new feature
	/// @param responsible - address responsible for funds.
	/// @param value - amount of tokens to be withdrawed.
	function withdrawForNewFeature(address responsible, uint256 value) external onlyManyOwners {
		token.transfer(responsible, value);
	}

	address Insurance; //todo add to constructor or change to custom address.
	uint256 public insuranceVault = 10 ** 8 * 10 ** 18 * 3 / 100;           // Total amount of tokens for insurance purposes, should be 3kk.
	
	/// @param value - amount of withdrawal.
	/// @notice Function for payout for Insurance
	function withdrawForInsurance(uint256 value) external onlyManyOwners {
		token.transfer(Insurance, value);
	}

	bool paidToGovernance = false;
	address governance; //todo add to constructor.
	uint256 public GovernanceRewardValue = 10 ** 8 * 10 ** 18 * 7 / 100;   // Total amount of tokens for governance rewards, should be 7kk.

	/// @notice Function for payout for governance
	function withdrawToGovernance() external onlyManyOwners {
		require(paidToGovernance = false, "already paid!");
		token.transfer(governance, GovernanceRewardValue);
		paidToGovernance = true;
	}

	bool PaidToAdvisors = false;
	address Advisors;//todo: add to constructor.
	uint256 public AdvisorsRewardValue = 10 ** 8 * 10 ** 18 * 195 / 10000;// Total amount of tokens for advisors, should be 195 000 000
	
	/// @notice Function for payout to advisors.
	function withdrawToAdvisors () external onlyManyOwners {
		require(PaidToAdvisors == false, "already paid!");
		token.transfer(AMA, AdvisorsRewardValue);
		PaidToAdvisors = true;
	}

	address public AMA; //todo: add to constructor.
	uint256 public amaRewardValue = 10 ** 8 * 10 ** 18 * 5 / 10000;      // Total amount of tokens for AMA, should be 50k.
	bool PaidToAMA = false;

	/// @notice Function for payout to .
	function withdrawToMarketing() external 
	{
		require(PaidToAMA == false, "already paid!");
		token.transfer(AMA, amaRewardValue);
		PaidToAMA = true;
	}

}