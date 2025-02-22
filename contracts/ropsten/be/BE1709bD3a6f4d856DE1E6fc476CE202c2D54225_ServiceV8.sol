// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import './interfaces/StrongPoolInterface.sol';

contract ServiceV8 {
  event Requested(address indexed miner);
  event Claimed(address indexed miner, uint256 reward);

  using SafeMath for uint256;
  bool public initDone;
  address public admin;
  address public pendingAdmin;
  address public superAdmin;
  address public pendingSuperAdmin;
  address public serviceAdmin;
  address public parameterAdmin;
  address payable public feeCollector;

  IERC20 public strongToken;
  StrongPoolInterface public strongPool;

  uint256 public rewardPerBlockNumerator;
  uint256 public rewardPerBlockDenominator;

  uint256 public naasRewardPerBlockNumerator;
  uint256 public naasRewardPerBlockDenominator;

  uint256 public claimingFeeNumerator;
  uint256 public claimingFeeDenominator;

  uint256 public requestingFeeInWei;

  uint256 public strongFeeInWei;

  uint256 public recurringFeeInWei;
  uint256 public recurringNaaSFeeInWei;
  uint256 public recurringPaymentCycleInBlocks;

  uint256 public rewardBalance;

  mapping(address => uint256) public entityBlockLastClaimedOn;

  address[] public entities;
  mapping(address => uint256) public entityIndex;
  mapping(address => bool) public entityActive;
  mapping(address => bool) public requestPending;
  mapping(address => bool) public entityIsNaaS;
  mapping(address => uint256) public paidOnBlock;
  uint256 public activeEntities;

  string public desciption;

  uint256 public claimingFeeInWei;

  uint256 public naasRequestingFeeInWei;

  uint256 public naasStrongFeeInWei;

  bool public removedTokens;

  mapping(address => uint256) public traunch;

  uint256 public currentTraunch;

  function init(
    address strongTokenAddress,
    address strongPoolAddress,
    address adminAddress,
    address superAdminAddress,
    uint256 rewardPerBlockNumeratorValue,
    uint256 rewardPerBlockDenominatorValue,
    uint256 naasRewardPerBlockNumeratorValue,
    uint256 naasRewardPerBlockDenominatorValue,
    uint256 requestingFeeInWeiValue,
    uint256 strongFeeInWeiValue,
    uint256 recurringFeeInWeiValue,
    uint256 recurringNaaSFeeInWeiValue,
    uint256 recurringPaymentCycleInBlocksValue,
    uint256 claimingFeeNumeratorValue,
    uint256 claimingFeeDenominatorValue,
    string memory desc
  ) public {
    require(!initDone, 'init done');
    strongToken = IERC20(strongTokenAddress);
    strongPool = StrongPoolInterface(strongPoolAddress);
    admin = adminAddress;
    superAdmin = superAdminAddress;
    rewardPerBlockNumerator = rewardPerBlockNumeratorValue;
    rewardPerBlockDenominator = rewardPerBlockDenominatorValue;
    naasRewardPerBlockNumerator = naasRewardPerBlockNumeratorValue;
    naasRewardPerBlockDenominator = naasRewardPerBlockDenominatorValue;
    requestingFeeInWei = requestingFeeInWeiValue;
    strongFeeInWei = strongFeeInWeiValue;
    recurringFeeInWei = recurringFeeInWeiValue;
    recurringNaaSFeeInWei = recurringNaaSFeeInWeiValue;
    claimingFeeNumerator = claimingFeeNumeratorValue;
    claimingFeeDenominator = claimingFeeDenominatorValue;
    recurringPaymentCycleInBlocks = recurringPaymentCycleInBlocksValue;
    desciption = desc;
    initDone = true;
  }

  // ADMIN
  // *************************************************************************************
  function updateServiceAdmin(address newServiceAdmin) public {
    require(msg.sender == superAdmin);
    serviceAdmin = newServiceAdmin;
  }

  function updateParameterAdmin(address newParameterAdmin) public {
    require(newParameterAdmin != address(0), 'zero');
    require(msg.sender == superAdmin);
    parameterAdmin = newParameterAdmin;
  }

  function updateFeeCollector(address payable newFeeCollector) public {
    require(newFeeCollector != address(0), 'zero');
    require(msg.sender == superAdmin);
    feeCollector = newFeeCollector;
  }

  function setPendingAdmin(address newPendingAdmin) public {
    require(msg.sender == admin, 'not admin');
    pendingAdmin = newPendingAdmin;
  }

  function acceptAdmin() public {
    require(msg.sender == pendingAdmin && msg.sender != address(0), 'not pendingAdmin');
    admin = pendingAdmin;
    pendingAdmin = address(0);
  }

  function setPendingSuperAdmin(address newPendingSuperAdmin) public {
    require(msg.sender == superAdmin, 'not superAdmin');
    pendingSuperAdmin = newPendingSuperAdmin;
  }

  function acceptSuperAdmin() public {
    require(msg.sender == pendingSuperAdmin && msg.sender != address(0), 'not pendingSuperAdmin');
    superAdmin = pendingSuperAdmin;
    pendingSuperAdmin = address(0);
  }

  // ENTITIES
  // *************************************************************************************
  function getEntities() public view returns (address[] memory) {
    return entities;
  }

  function isEntityActive(address entity) public view returns (bool) {
    return entityActive[entity];
  }

  // TRAUNCH
  // *************************************************************************************
  function updateCurrentTraunch(uint256 value) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    currentTraunch = value;
  }

  function getTraunch(address entity) public view returns (uint256) {
    return traunch[entity];
  }

  // REWARD
  // *************************************************************************************
  function updateRewardPerBlock(uint256 numerator, uint256 denominator) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    require(denominator != 0, 'invalid value');
    rewardPerBlockNumerator = numerator;
    rewardPerBlockDenominator = denominator;
  }

  function updateNaaSRewardPerBlock(uint256 numerator, uint256 denominator) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    require(denominator != 0, 'invalid value');
    naasRewardPerBlockNumerator = numerator;
    naasRewardPerBlockDenominator = denominator;
  }

  function deposit(uint256 amount) public {
    require(msg.sender == superAdmin, 'not an admin');
    require(amount > 0, 'zero');
    strongToken.transferFrom(msg.sender, address(this), amount);
    rewardBalance = rewardBalance.add(amount);
  }

  function withdraw(address destination, uint256 amount) public {
    require(msg.sender == superAdmin, 'not an admin');
    require(amount > 0, 'zero');
    require(rewardBalance >= amount, 'not enough');
    strongToken.transfer(destination, amount);
    rewardBalance = rewardBalance.sub(amount);
  }

  function removeTokens() public {
    require(!removedTokens, 'already removed');
    require(msg.sender == superAdmin, 'not an admin');
    // removing 2500 STRONG tokens sent in this tx: 0xe27640beda32a5e49aad3b6692790b9d380ed25da0cf8dca7fd5f3258efa600a
    strongToken.transfer(superAdmin, 2500000000000000000000);
    removedTokens = true;
  }

  // FEES
  // *************************************************************************************
  function updateRequestingFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    requestingFeeInWei = feeInWei;
  }

  function updateStrongFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    strongFeeInWei = feeInWei;
  }

  function updateNaasRequestingFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    naasRequestingFeeInWei = feeInWei;
  }

  function updateNaasStrongFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    naasStrongFeeInWei = feeInWei;
  }

  function updateClaimingFee(uint256 numerator, uint256 denominator) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    require(denominator != 0, 'invalid value');
    claimingFeeNumerator = numerator;
    claimingFeeDenominator = denominator;
  }

  function updateRecurringFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    recurringFeeInWei = feeInWei;
  }

  function updateRecurringNaaSFee(uint256 feeInWei) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    recurringNaaSFeeInWei = feeInWei;
  }

  function updateRecurringPaymentCycleInBlocks(uint256 blocks) public {
    require(msg.sender == admin || msg.sender == parameterAdmin || msg.sender == superAdmin, 'not an admin');
    require(blocks > 0, 'zero');
    recurringPaymentCycleInBlocks = blocks;
  }

  // CORE
  // *************************************************************************************
  function requestAccess(bool isNaaS) public payable {
    require(!entityActive[msg.sender], 'active');
    uint256 rFee;
    uint256 sFee;
    if (isNaaS) {
      rFee = naasRequestingFeeInWei;
      sFee = naasStrongFeeInWei;
      uint256 len = entities.length;
      entityIndex[msg.sender] = len;
      entities.push(msg.sender);
      entityActive[msg.sender] = true;
      requestPending[msg.sender] = false;
      activeEntities = activeEntities.add(1);
      entityBlockLastClaimedOn[msg.sender] = block.number;
      paidOnBlock[msg.sender] = block.number;
    } else {
      rFee = requestingFeeInWei;
      sFee = strongFeeInWei;
      requestPending[msg.sender] = true;
    }
    entityIsNaaS[msg.sender] = isNaaS;
    require(msg.value == rFee, 'invalid fee');
    feeCollector.transfer(msg.value);
    strongToken.transferFrom(msg.sender, address(this), sFee);
    strongToken.transfer(feeCollector, sFee);
    traunch[msg.sender] = currentTraunch;
    emit Requested(msg.sender);
  }

  function grantAccess(
    address[] memory ents,
    bool[] memory entIsNaaS,
    bool useChecks
  ) public {
    require(msg.sender == admin || msg.sender == serviceAdmin || msg.sender == superAdmin, 'not admin');
    require(ents.length > 0, 'zero');
    require(ents.length == entIsNaaS.length, 'lengths dont match');
    for (uint256 i = 0; i < ents.length; i++) {
      address entity = ents[i];
      bool naas = entIsNaaS[i];
      if (useChecks) {
        require(requestPending[entity], 'not pending');
        require(entityIsNaaS[entity] == naas, 'naas no match');
      }
      require(!entityActive[entity], 'exists');
      uint256 len = entities.length;
      entityIndex[entity] = len;
      entities.push(entity);
      entityActive[entity] = true;
      requestPending[entity] = false;
      entityIsNaaS[entity] = naas;
      activeEntities = activeEntities.add(1);
      entityBlockLastClaimedOn[entity] = block.number;
      paidOnBlock[entity] = block.number;
      traunch[entity] = currentTraunch;
    }
  }

  function setEntityActiveStatus(address entity, bool status) public {
    require(msg.sender == admin || msg.sender == serviceAdmin || msg.sender == superAdmin, 'not admin');
    uint256 index = entityIndex[entity];
    require(entities[index] == entity, 'invalid entity');
    require(entityActive[entity] != status, 'already set');
    entityActive[entity] = status;
    if (status) {
      activeEntities = activeEntities.add(1);
      entityBlockLastClaimedOn[entity] = block.number;
    } else {
      if (block.number > entityBlockLastClaimedOn[entity]) {
        uint256 reward = getReward(entity);
        if (reward > 0) {
          rewardBalance = rewardBalance.sub(reward);
          strongToken.approve(address(strongPool), reward);
          strongPool.mineFor(entity, reward);
        }
      }
      activeEntities = activeEntities.sub(1);
      entityBlockLastClaimedOn[entity] = 0;
    }
  }

  function setEntityIsNaaS(address entity, bool isNaaS) public {
    require(msg.sender == admin || msg.sender == serviceAdmin || msg.sender == superAdmin, 'not admin');
    uint256 index = entityIndex[entity];
    require(entities[index] == entity, 'invalid entity');

    entityIsNaaS[entity] = isNaaS;
  }

  function setTraunch(address entity, uint256 value) public {
    require(msg.sender == admin || msg.sender == serviceAdmin || msg.sender == superAdmin, 'not admin');
    uint256 index = entityIndex[entity];
    require(entities[index] == entity, 'invalid entity');

    traunch[entity] = value;
  }

  function payFee() public payable {
    if (entityIsNaaS[msg.sender]) {
      require(msg.value == recurringNaaSFeeInWei, 'naas fee');
    } else {
      require(msg.value == recurringFeeInWei, 'basic fee');
    }
    feeCollector.transfer(msg.value);
    paidOnBlock[msg.sender] = paidOnBlock[msg.sender].add(recurringPaymentCycleInBlocks);
  }

  function getReward(address entity) public view returns (uint256) {
    if (activeEntities == 0) return 0;
    if (entityBlockLastClaimedOn[entity] == 0) return 0;
    uint256 blockResult = block.number.sub(entityBlockLastClaimedOn[entity]);
    uint256 rewardNumerator;
    uint256 rewardDenominator;
    if (entityIsNaaS[entity]) {
      rewardNumerator = naasRewardPerBlockNumerator;
      rewardDenominator = naasRewardPerBlockDenominator;
    } else {
      rewardNumerator = rewardPerBlockNumerator;
      rewardDenominator = rewardPerBlockDenominator;
    }
    uint256 rewardPerBlockResult = blockResult.mul(rewardNumerator).div(rewardDenominator);
    return rewardPerBlockResult.div(activeEntities);
  }

  function getRewardByBlock(address entity, uint256 blockNumber) public view returns (uint256) {
    if (blockNumber > block.number) return 0;
    if (entityBlockLastClaimedOn[entity] == 0) return 0;
    if (blockNumber < entityBlockLastClaimedOn[entity]) return 0;
    if (activeEntities == 0) return 0;
    uint256 blockResult = blockNumber.sub(entityBlockLastClaimedOn[entity]);
    uint256 rewardNumerator;
    uint256 rewardDenominator;
    if (entityIsNaaS[entity]) {
      rewardNumerator = naasRewardPerBlockNumerator;
      rewardDenominator = naasRewardPerBlockDenominator;
    } else {
      rewardNumerator = rewardPerBlockNumerator;
      rewardDenominator = rewardPerBlockDenominator;
    }
    uint256 rewardPerBlockResult = blockResult.mul(rewardNumerator).div(rewardDenominator);
    return rewardPerBlockResult.div(activeEntities);
  }

  function claim(uint256 blockNumber, bool toStrongPool) public payable {
    require(blockNumber <= block.number, 'invalid block number');
    require(entityBlockLastClaimedOn[msg.sender] != 0, 'error');
    require(blockNumber > entityBlockLastClaimedOn[msg.sender], 'too soon');
    require(entityActive[msg.sender], 'not active');
    require(paidOnBlock[msg.sender] != 0, 'zero');
    if (
      (entityIsNaaS[msg.sender] && recurringNaaSFeeInWei != 0) || (!entityIsNaaS[msg.sender] && recurringFeeInWei != 0)
    ) {
      require(blockNumber < paidOnBlock[msg.sender].add(recurringPaymentCycleInBlocks), 'pay fee');
    }

    uint256 reward = getRewardByBlock(msg.sender, blockNumber);
    require(reward > 0, 'no reward');
    uint256 fee = reward.mul(claimingFeeNumerator).div(claimingFeeDenominator);
    require(msg.value == fee, 'invalid fee');
    feeCollector.transfer(msg.value);
    if (toStrongPool) {
      strongToken.approve(address(strongPool), reward);
      strongPool.mineFor(msg.sender, reward);
    } else {
      strongToken.transfer(msg.sender, reward);
    }
    rewardBalance = rewardBalance.sub(reward);
    entityBlockLastClaimedOn[msg.sender] = blockNumber;
    emit Claimed(msg.sender, reward);
  }
}