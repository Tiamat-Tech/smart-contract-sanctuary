// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./XP.sol";

interface IWhitelistRegistry {
  function IsWhitelisted(address _addr) external view returns (bool);
}

contract XPFarm is Ownable {
  XpToken private XPToken;

  struct stakingInfo {
    uint256 stakeIndex;
    uint256 stakeDeposited;
    uint256 stakingBalance;
    uint256 stakingPeriodStartDate;
    uint256 stakingPeriodEndDate;
    bool isStakeClaimed;
    uint256 rewardAmount;
  }

  struct PoolInfo {
    IERC20 richAddress;
    uint256 totalAmountStaked;
    // for contract purpose
    // RICH-LP have different formula for XP token
    bool isRichLP;
  }

  PoolInfo[] public poolInfo;

  mapping(uint256 => mapping(address => stakingInfo[])) private StakeholderInfo;
  mapping(address => bool) public hasStaked;

  mapping(uint256 => uint256) Factor;

  // 10000 -> 100%
  // 1000 -> 10%
  // 100 -> 1%
  // 10 -> 0.1%
  uint256 public penaltyFees = 3000; // 3000 -> 30%
  address treasuryAddress = 0x2E3c462e0884855650fDd8d44EA8fE7C097BaF9C; // this address is for testing purpose
  IWhitelistRegistry private whitelistRegistry;

  uint256 public maxStakePeriod = 365;

  event TokenStaked(address indexed from, uint256 amount);
  event IssuedTokens(address indexed to, uint256 amount);
  event TokenUnstaked(address indexed recipient, uint256 amount);
  event PenaltyApplied(
    address indexed recipient,
    uint256 penaltyAmount,
    uint256 claimableBalance
  );

  /**
   * @param _richToken address of RICH
   * @param _rewardToken address of XP
   * @param _treasuryAddress address where some penalty will be sent
   * @param _whitelistRegistry address of contract that maintains whitelisted addresses
   */
  constructor(
    IERC20 _richToken,
    XpToken _rewardToken,
    address _treasuryAddress,
    IWhitelistRegistry _whitelistRegistry
  ) Ownable() {
    poolInfo.push(PoolInfo(_richToken, 0, false));
    XPToken = _rewardToken;
    treasuryAddress = _treasuryAddress;
    whitelistRegistry = _whitelistRegistry;

    // 1.02 ^ (number of days)
    // pre-computation
    Factor[1] = 1020000000000;
    // for (uint256 i = 2; i <= 365; i++) {
    //   Factor[i] = (Factor[i - 1] * 102) / 100;
    // }
  }

  /**
    @notice function to stake any of the RICH or RICH-LP tokens
    @param _amount amount of the tokens to be staked
    @param _days number of days to stake
    @param _richTokenIndex index of the token which is to be staked (0 for RICH)
  */
  function stakeTokens(
    uint256 _amount,
    uint256 _days,
    uint256 _richTokenIndex
  ) public {
    require(
      whitelistRegistry.IsWhitelisted(msg.sender),
      "address not whitelisted"
    );
    require(_days >= 1, "stake period is not within limits");
    require(_days <= maxStakePeriod, "stake period is not within limits");
    require(_amount > 0, "some staking amount required!");
    require(_richTokenIndex <= poolInfo.length - 1, "invalid stake token");

    // dynamically calculating start and end date
    uint256 _stakePeriodStartDate = block.timestamp;
    uint256 _stakePeriodEndDate = _stakePeriodStartDate + _days * 86400;

    // getting info about the token that user wants to stake
    PoolInfo storage pool = poolInfo[_richTokenIndex];

    pool.richAddress.transferFrom(msg.sender, address(this), _amount);
    pool.totalAmountStaked = pool.totalAmountStaked + _amount;

    hasStaked[msg.sender] = true;

    uint256 rewardAmount = _calculateXP(_amount, _days, pool.isRichLP);

    _issueRewardTokens(msg.sender, rewardAmount);

    StakeholderInfo[_richTokenIndex][msg.sender].push(
      stakingInfo(
        StakeholderInfo[_richTokenIndex][msg.sender].length,
        _amount,
        _amount,
        _stakePeriodStartDate,
        _stakePeriodEndDate,
        false,
        rewardAmount
      )
    );

    emit TokenStaked(msg.sender, _amount);
  }

  /**
    @notice function to unstake the staked tokens
    @param _stakeIndex which stake to unstake from
    @param _richTokenIndex which token to unstake (0 -> RICH, 1... -> RICHLP)
  */
  function unstakeTokens(uint256 _stakeIndex, uint256 _richTokenIndex) public {
    require(hasStaked[msg.sender], "You are not a stakeholder");
    require(_richTokenIndex <= poolInfo.length - 1, "invalid stake token");

    stakingInfo memory StakeInfo = StakeholderInfo[_richTokenIndex][msg.sender][
      _stakeIndex
    ];
    require(StakeInfo.stakingBalance > 0, "staking balance is 0");

    PoolInfo storage pool = poolInfo[_richTokenIndex];

    uint256 claimableBalance = StakeInfo.stakingBalance;
    uint256 penaltyAmount = 0;
    uint256 burnAmount = 0;
    uint256 treasuryAmount = 0;

    // Check if staker is claiming before staking period ends
    if (block.timestamp < StakeInfo.stakingPeriodEndDate) {
      claimableBalance =
        (StakeInfo.stakingBalance * (10000 - penaltyFees)) /
        10000;
      penaltyAmount = StakeInfo.stakingBalance - claimableBalance;

      // send 10% to burn address
      burnAmount = (StakeInfo.stakingBalance * 1000) / 10000;
      pool.richAddress.transfer(
        0x000000000000000000000000000000000000dEaD,
        burnAmount
      );

      // send 20% to specified DAO address
      treasuryAmount = (StakeInfo.stakingBalance * 2000) / 10000;
      pool.richAddress.transfer(treasuryAddress, treasuryAmount);

      emit PenaltyApplied(msg.sender, penaltyAmount, claimableBalance);
    }

    pool.richAddress.transfer(msg.sender, claimableBalance);
    pool.totalAmountStaked = pool.totalAmountStaked - StakeInfo.stakingBalance;

    StakeholderInfo[_richTokenIndex][msg.sender][_stakeIndex]
      .stakingBalance = 0;
    StakeholderInfo[_richTokenIndex][msg.sender][_stakeIndex]
      .isStakeClaimed = true;

    emit TokenUnstaked(msg.sender, claimableBalance);
  }

  /**
    @notice admin function to update the penalty fees
    @param _penaltyFees percentage of penalty fees (100% => 10000)
  */
  function updatePenaltyFees(uint256 _penaltyFees) public onlyOwner {
    penaltyFees = _penaltyFees;
  }

  /**
    @notice admin function to change the whitelistRegistry contract
    @param _whitelistRegistry address of the whitelistRegistry contract
  */
  function changeWhitelistRegistry(IWhitelistRegistry _whitelistRegistry)
    public
    onlyOwner
  {
    whitelistRegistry = _whitelistRegistry;
  }

  /**
    @notice admin function to add a new RICH-LP token address for staking
    @param _token address of RICH-LP token
  */
  function addNewToken(IERC20 _token) public onlyOwner {
    require(_token != IERC20(address(0)), "invalid token address");
    poolInfo.push(PoolInfo(_token, 0, true));
  }

  /**
    @notice admin function to update the treasury address
    @notice treasury address - address where penalty fees is to be sent
    @param _address treasury address
  */
  function updateTreasuryAddress(address _address) public onlyOwner {
    require(_address != address(0), "invalid address");
    treasuryAddress = _address;
  }

  // utility functions
  function getNumberOfStakes(address _stakeHolder, uint256 _richTokenIndex)
    public
    view
    returns (uint256)
  {
    return StakeholderInfo[_richTokenIndex][_stakeHolder].length;
  }

  function getUserStake(
    address _stakeHolder,
    uint256 _richTokenIndex,
    uint256 _stakeIndex
  ) public view returns (stakingInfo memory) {
    return StakeholderInfo[_richTokenIndex][_stakeHolder][_stakeIndex];
  }

  // some internal functions
  function _issueRewardTokens(address _recipient, uint256 _amount) internal {
    XPToken.mint(_recipient, _amount);
    emit IssuedTokens(_recipient, _amount);
  }

  function _calculateXP(
    uint256 _amount,
    uint256 _days,
    bool isRichLP
  ) public view returns (uint256) {
    uint256 amountOfXP = (_amount * Factor[_days]) / 1000000000000;

    if (isRichLP) {
      amountOfXP = 3 * amountOfXP;
    }

    return amountOfXP;
  }
}