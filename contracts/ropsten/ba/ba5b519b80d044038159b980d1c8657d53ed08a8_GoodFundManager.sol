// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../reserve/GoodReserveCDai.sol";
import "../Interfaces.sol";
import "../utils/DSMath.sol";
import "../utils/DAOUpgradeableContract.sol";

/**
 * @title GoodFundManager contract that transfer interest from the staking contract
 * to the reserve contract and transfer the return mintable tokens to the staking
 * contract
 * cDAI support only
 */
contract GoodFundManager is DAOUpgradeableContract, DSMath {
	// timestamp that indicates last time that interests collected
	uint256 public lastCollectedInterest;
	// Gas cost for mint ubi+bridge ubi+mint rewards
	uint256 public gasCostExceptInterestCollect;
	// Gas cost for minting GD for keeper
	uint256 public gdMintGasCost;
	// how much time since last collectInterest should pass in order to cancel gas cost multiplier requirement for next collectInterest
	uint256 public collectInterestTimeThreshold;
	// to allow keeper to collect interest, total interest collected should be interestMultiplier*gas costs
	uint8 public interestMultiplier;
	//address of the active staking contracts
	address[] public activeContracts;
	event GasCostSet(uint256 timestamp, uint256 newGasCost);
	event CollectInterestTimeThresholdSet(
		uint256 timestamp,
		uint256 newCollectInterestTimeThreshold
	);
	event InterestMultiplierSet(uint256 timestamp, uint8 newInterestMultiplier);
	event GasCostExceptInterestCollectSet(
		uint256 timestamp,
		uint256 newGasCostExceptInterestCollect
	);
	event StakingRewardSet(
		uint256 timestamp,
		uint32 _rewardsPerBlock,
		address _stakingAddress,
		uint32 _blockStart,
		uint32 _blockEnd,
		bool _isBlackListed
	);
	//Structure that hold reward information and if its blacklicksted or not for particular staking Contract
	struct Reward {
		uint32 blockReward; //in G$
		uint64 blockStart; // # of the start block to distribute rewards
		uint64 blockEnd; // # of the end block to distribute rewards
		bool isBlackListed; // If staking contract is blacklisted or not
	}
	// Rewards per block for particular Staking contract
	mapping(address => Reward) public rewardsForStakingContract;
	// Emits when `transferInterest` transfers
	// funds to the staking contract and to
	// the bridge
	event FundsTransferred(
		// The caller address
		address indexed caller,
		// The staking contract address
		//address indexed staking,
		// The reserve contract address
		address reserve,
		//addresses of the staking contracts
		address[] stakings,
		// Amount of cDai that was transferred
		// from the staking contract to the
		// reserve contract
		uint256 cDAIinterestEarned,
		// The number of tokens that have been minted
		// by the reserve to the staking contract
		//uint256 gdInterest,
		// The number of tokens that have been minted
		// by the reserve to the bridge which in his
		// turn should transfer those funds to the
		// sidechain
		uint256 gdUBI,
		// Amount of GD to be minted as reward
		//to the keeper which collect interests
		uint256 gdReward
	);

	event StakingRewardMinted(
		address stakingContract,
		address staker,
		uint256 gdReward
	);

	/**
	 * @dev Constructor
	 * @param _ns The address of the name Service
	 */
	function initialize(INameService _ns) public virtual initializer {
		setDAO(_ns);
		gdMintGasCost = 250000; // While testing highest amount was 240k so put 250k to be safe
		collectInterestTimeThreshold = 5184000; // 5184000 is 2 months in seconds
		interestMultiplier = 4;
		gasCostExceptInterestCollect = 850000; //while testing highest amount was 800k so put 850k to be safe
	}

	/**
	 * @dev Set gas cost to mint GD rewards for keeper
	 * @param _gasAmount amount of gas it costs for minting gd reward
	 */
	function setGasCost(uint256 _gasAmount) public {
		_onlyAvatar();
		gdMintGasCost = _gasAmount;
		emit GasCostSet(block.timestamp, _gasAmount);
	}

	/**
	 * @dev Set collectInterestTimeThreshold to determine how much time should pass after collectInterest called
	 * after which we ignore the interest>=multiplier*gas costs limit
	 * @param _timeThreshold new threshold in seconds
	 */
	function setCollectInterestTimeThreshold(uint256 _timeThreshold) public {
		_onlyAvatar();
		collectInterestTimeThreshold = _timeThreshold;
		emit CollectInterestTimeThresholdSet(block.timestamp, _timeThreshold);
	}

	/**
	 * @dev Set multiplier to determine how much times larger should be collected interest than spent gas when collectInterestTimeThreshold did not pass
	 */
	function setInterestMultiplier(uint8 _newMultiplier) public {
		_onlyAvatar();
		interestMultiplier = _newMultiplier;
		emit InterestMultiplierSet(block.timestamp, _newMultiplier);
	}

	/**
	 * @dev Set Gas cost for required transactions after collecting interest in collectInterest function
	 * we need this to know if caller has enough gas left to keep collecting interest
	 * @dev _gasAmount The gas amount that needed for transactions
	 */
	function setGasCostExceptInterestCollect(uint256 _gasAmount) public {
		_onlyAvatar();
		gasCostExceptInterestCollect = _gasAmount;
		emit GasCostExceptInterestCollectSet(block.timestamp, _gasAmount);
	}

	/**
	 * @dev Sets the Reward for particular Staking contract
	 * @param _rewardsPerBlock reward for per block
	 * @param _stakingAddress address of the staking contract
	 * @param _blockStart block number for start reward distrubution
	 * @param _blockEnd block number for end reward distrubition
	 * @param _isBlackListed set staking contract blacklisted or not to prevent minting
	 */
	function setStakingReward(
		uint32 _rewardsPerBlock,
		address _stakingAddress,
		uint32 _blockStart,
		uint32 _blockEnd,
		bool _isBlackListed
	) public {
		_onlyAvatar();

		//we dont allow to undo blacklisting as it will mess up rewards accounting.
		//staking contracts are assumed immutable and thus non fixable
		require(
			(_isBlackListed ||
				!rewardsForStakingContract[_stakingAddress].isBlackListed),
			"can't undo blacklisting"
		);
		Reward memory reward = Reward(
			_rewardsPerBlock,
			_blockStart > 0 ? _blockStart : uint32(block.number),
			_blockEnd > 0 ? _blockEnd : 0xFFFFFFFF,
			_isBlackListed
		);
		rewardsForStakingContract[_stakingAddress] = reward;

		bool exist;
		uint8 i;
		for (i = 0; i < activeContracts.length; i++) {
			if (activeContracts[i] == _stakingAddress) {
				exist = true;
				break;
			}
		}

		if (exist && (_isBlackListed || _rewardsPerBlock == 0)) {
			activeContracts[i] = activeContracts[activeContracts.length - 1];
			activeContracts.pop();
		} else if (!exist && !(_isBlackListed || _rewardsPerBlock == 0)) {
			activeContracts.push(_stakingAddress);
		}
		emit StakingRewardSet(
			block.timestamp,
			_rewardsPerBlock,
			_stakingAddress,
			_blockStart,
			_blockEnd,
			_isBlackListed
		);
	}

	/**
	 * @dev Collects UBI interest in iToken from a given staking contract and transfers
	 * that interest to the reserve contract. Then transfers the given gd which
	 * received from the reserve contract back to the staking contract and to the
	 * bridge, which locks the funds and then the GD tokens are been minted to the
	 * given address on the sidechain
	 * @param _stakingContracts from which contracts to collect interest
	 */
	function collectInterest(address[] memory _stakingContracts) public {
		uint256 initialGas = gasleft();
		cERC20 iToken = cERC20(nameService.getAddress("CDAI"));
		ERC20 daiToken = ERC20(nameService.getAddress("DAI"));
		address reserveAddress = nameService.getAddress("RESERVE");
		// DAI balance of the reserve contract
		uint256 currentBalance = daiToken.balanceOf(reserveAddress);
		uint256 startingCDAIBalance = iToken.balanceOf(reserveAddress);
		for (uint256 i = _stakingContracts.length - 1; i >= 0; i--) {
			// elements are sorted by balances from lowest to highest

			if (_stakingContracts[i] != address(0x0)) {
				IGoodStaking(_stakingContracts[i]).collectUBIInterest(
					reserveAddress
				);
			}

			if (i == 0) break; // when active contracts length is 1 then gives error
		}
		// Finds the actual transferred DAI
		uint256 daiToConvert = daiToken.balanceOf(reserveAddress) -
			currentBalance;

		// Mints gd while the interest amount is equal to the transferred amount
		(uint256 gdUBI, uint256 interestInCdai) = GoodReserveCDai(
			reserveAddress
		).mintUBI(daiToConvert, startingCDAIBalance, iToken);

		IGoodDollar token = IGoodDollar(nameService.getAddress("GOODDOLLAR"));
		if (gdUBI > 0) {
			//transfer ubi to avatar on sidechain via bridge
			require(
				token.transferAndCall(
					nameService.getAddress("BRIDGE_CONTRACT"),
					gdUBI,
					abi.encodePacked(nameService.getAddress("UBI_RECIPIENT"))
				),
				"ubi bridge transfer failed"
			);
		}
		uint256 totalUsedGas = ((initialGas - gasleft() + gdMintGasCost) *
			110) / 100; // We will return as reward 1.1x of used gas in GD
		uint256 gdRewardToMint = getGasPriceInGD(totalUsedGas);

		GoodReserveCDai(reserveAddress).mintRewardFromRR(
			nameService.getAddress("CDAI"),
			msg.sender,
			gdRewardToMint
		);

		emit FundsTransferred(
			msg.sender,
			reserveAddress,
			_stakingContracts,
			interestInCdai,
			gdUBI,
			gdRewardToMint
		);

		uint256 gasPriceIncDAI = getGasPriceIncDAIorDAI(
			initialGas - gasleft(),
			false
		);

		if (
			block.timestamp >=
			lastCollectedInterest + collectInterestTimeThreshold
		) {
			require(
				interestInCdai >= gasPriceIncDAI,
				"Collected interest value should be larger than spent gas costs"
			); // This require is necessary to keeper can not abuse this function
		} else {
			require(
				interestInCdai >= interestMultiplier * gasPriceIncDAI,
				"Collected interest value should be interestMultiplier x gas costs"
			);
		}
		lastCollectedInterest = block.timestamp;
	}

	/**
	 * @dev  Function that get addresses of staking contracts that we can collect interest from with a specific gas limit
	 * but that also pass the interest>=gascosts*multiplier
	 * @param _maxGasAmount The maximum amount of the gas that keeper willing to spend collect interests
	 * @return addresses of the staking contracts to the collect interests
	 */
	function calcSortedContracts(uint256 _maxGasAmount)
		public
		view
		returns (address[] memory)
	{
		uint256 activeContractsLength = activeContracts.length;
		address[] memory addresses = new address[](activeContractsLength);
		uint256[] memory balances = new uint256[](activeContractsLength);
		uint256 tempInterest;
		int256 i;
		for (i = 0; i < int256(activeContractsLength); i++) {
			(, , , , tempInterest) = IGoodStaking(activeContracts[uint256(i)])
				.currentGains(false, true);
			if (tempInterest != 0) {
				addresses[uint256(i)] = activeContracts[uint256(i)];
				balances[uint256(i)] = tempInterest;
			}
		}
		uint256 gasCostInDAI = getGasPriceIncDAIorDAI(_maxGasAmount, true); // Get gas price in DAI so can compare with possible interest amount to get
		address[] memory emptyArray = new address[](0);

		quick(balances, addresses); // sort the values according to interest balance
		uint256 gasCost;
		uint256 possibleCollected;
		for (i = int256(activeContractsLength) - 1; i >= 0; i--) {
			// elements are sorted by balances from lowest to highest

			if (addresses[uint256(i)] != address(0x0)) {
				gasCost = IGoodStaking(addresses[uint256(i)])
					.getGasCostForInterestTransfer();
				if (_maxGasAmount - gasCost >= gasCostExceptInterestCollect) {
					// collects the interest from the staking contract and transfer it directly to the reserve contract
					//`collectUBIInterest` returns (iTokengains, tokengains, precission loss, donation ratio)
					possibleCollected += balances[uint256(i)];
					_maxGasAmount = _maxGasAmount - gasCost;
				} else {
					break;
				}
			} else {
				break; // if addresses are null after this element then break because we initialize array in size activecontracts but if their interest balance is zero then we dont put it in this array
			}
		}
		while (i > -1) {
			addresses[uint256(i)] = address(0x0);
			i -= 1;
		}
		if (
			block.timestamp >=
			lastCollectedInterest + collectInterestTimeThreshold
		) {
			if (possibleCollected * 1e10 < gasCostInDAI) return emptyArray; // multiply possiblecollected by 1e10 so it will be on the 18decimals
		} else {
			// multiply possiblecollected by 1e10 so it will be on the 18decimals
			if (possibleCollected * 1e10 < interestMultiplier * gasCostInDAI)
				return emptyArray;
		}
		return addresses;
	}

	/**
	 * @dev Mint to users reward tokens which they earned by staking contract
	 * @param _token reserve token (currently can be just cDAI)
	 * @param _user user to get rewards
	 */
	function mintReward(address _token, address _user) public {
		Reward memory staking = rewardsForStakingContract[address(msg.sender)];
		require(staking.blockStart > 0, "Staking contract not registered");
		uint256 amount = IGoodStaking(address(msg.sender)).rewardsMinted(
			_user,
			staking.blockReward,
			staking.blockStart,
			staking.blockEnd
		);
		if (amount > 0 && staking.isBlackListed == false) {
			GoodReserveCDai(nameService.getAddress("RESERVE")).mintRewardFromRR(
					_token,
					_user,
					amount
				);

			emit StakingRewardMinted(msg.sender, _user, amount);
		}
	}

	/// quick sort
	function quick(uint256[] memory data, address[] memory addresses)
		internal
		pure
	{
		if (data.length > 1) {
			quickPart(data, addresses, 0, data.length - 1);
		}
	}

	/**
     @dev quicksort algorithm to sort array
     */
	function quickPart(
		uint256[] memory data,
		address[] memory addresses,
		uint256 low,
		uint256 high
	) internal pure {
		if (low < high) {
			uint256 pivotVal = data[(low + high) / 2];

			uint256 low1 = low;
			uint256 high1 = high;
			for (;;) {
				while (data[low1] < pivotVal) low1++;
				while (data[high1] > pivotVal) high1--;
				if (low1 >= high1) break;
				(data[low1], data[high1]) = (data[high1], data[low1]);
				(addresses[low1], addresses[high1]) = (
					addresses[high1],
					addresses[low1]
				);
				low1++;
				high1--;
			}
			if (low < high1) quickPart(data, addresses, low, high1);
			high1++;
			if (high1 < high) quickPart(data, addresses, high1, high);
		}
	}

	/**
     @dev Helper function to get gasPrice in GWEI then change it to cDAI/DAI
     @param _gasAmount gas amount to get its value
	 @param _inDAI indicates if result should return in DAI
     @return Price of the gas in DAI/cDAI
     */
	function getGasPriceIncDAIorDAI(uint256 _gasAmount, bool _inDAI)
		public
		view
		returns (uint256)
	{
		AggregatorV3Interface gasPriceOracle = AggregatorV3Interface(
			nameService.getAddress("GAS_PRICE_ORACLE")
		);
		int256 gasPrice = gasPriceOracle.latestAnswer(); // returns gas price in 0 decimal as GWEI so 1eth / 1e9 eth

		AggregatorV3Interface daiETHOracle = AggregatorV3Interface(
			nameService.getAddress("DAI_ETH_ORACLE")
		);
		int256 daiInETH = daiETHOracle.latestAnswer(); // returns DAI price in ETH

		uint256 result = ((uint256(gasPrice) * 1e18) / uint256(daiInETH)); // Gasprice in GWEI and daiInETH is 18 decimals so we multiply gasprice with 1e18 in order to get result in 18 decimals
		if (_inDAI) return result * _gasAmount;
		result =
			(((result / 1e10) * 1e28) /
				cERC20(nameService.getAddress("CDAI")).exchangeRateStored()) *
			_gasAmount; // based on https://compound.finance/docs#protocol-math
		return result;
	}

	/**
     @dev Helper function to get gasPrice in G$, used to calculate the rewards for collectInterest KEEPER
     @param _gasAmount gas amount to get its value
     @return Price of the gas in G$
     */
	function getGasPriceInGD(uint256 _gasAmount) public view returns (uint256) {
		uint256 priceInCdai = getGasPriceIncDAIorDAI(_gasAmount, false);
		uint256 gdPriceIncDAI = GoodReserveCDai(
			nameService.getAddress("RESERVE")
		).currentPrice();
		return rdiv(priceInCdai, gdPriceIncDAI) / 1e25; // rdiv returns result in 27 decimals since GD$ in 2 decimals then divide 1e25
	}

	function getActiveContractsCount() public view returns (uint256) {
		return activeContracts.length;
	}
}