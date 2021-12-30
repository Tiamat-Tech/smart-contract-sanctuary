//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ServiceV1 {
  event Claimed(address indexed entity, uint256 reward);
  event Paid(address indexed entity, uint128 nodeId, uint256 upToBlockNumber);
  event Created(address indexed entity, bytes nodeId, uint256 blockNumber, uint256 paidOn);

  struct NodeEntity {
      string name;
      uint256 creationBlockNumber;
      uint256 lastClaimBlockNumber;
      uint256 lastPaidBlockNumber;
  }

  mapping(bytes => uint256) public entityNodePaidOnBlock;
  mapping(bytes => uint256) public entityNodeClaimedOnBlock;
  mapping(address => uint128) public entityNodeCount;
  mapping(address => bool) public _isBlacklisted;

  IERC20 public nodeifyToken;
  address public admin = 0xE5CaB58b538CC570388bF8550B5Ecb71A824EFB4;
  address public feeCollectorAddress = 0x0788a572c51802eEF7d198afaD100627B59e9DEC;
  uint128 public maxNodesPerAddress = 100;
  uint256 public nodePrice = 100000000000000000000 wei;
  uint256 public totalNodesCreated;
  uint256 public nodeifyFeeInWei = 29296162291357 wei; // $10~ USD
  uint256 public requestingFeeInWei = 29296162291357 wei; // $10~ USD
  uint128 public rewardPerBlock = 70000000000000000 wei;
  uint128 public maxPaymentPeriods = 3;
  uint256 public rewardBalance;
  uint256 public gracePeriodInBlocks = 70000;
  uint256 public recurringPaymentCycleInBlocks = 210000;
  uint256 public recurringFeeInWei = 29296162291357 wei; // $10~ USD
  uint256 public claimingFeeNumerator = 2; // 4%
  uint256 public claimingFeeDenominator = 50; // 4%

  constructor(address _nodeifyTokenAddress) {
    nodeifyToken = IERC20(_nodeifyTokenAddress);
  }

  function createNode(string memory name) public payable {
      require(entityNodeCount[msg.sender] < maxNodesPerAddress, "limit reached");
      require(
          bytes(name).length > 3 && bytes(name).length < 32,
          "Name Size Invalid"
      );
      require(
          msg.sender != address(0),
          "Creation from the zero address"
      );
      require(!_isBlacklisted[msg.sender], "Blacklisted address");
      require(
          nodeifyToken.balanceOf(msg.sender) >= nodePrice,
          "Balance too low for creation"
      );

      uint128 nodeId = entityNodeCount[msg.sender] + 1;
      bytes memory id = getNodeId(msg.sender, nodeId);

      uint256 rFee;
      uint256 nFee;

      entityNodePaidOnBlock[id] = block.number;
      entityNodeClaimedOnBlock[id] = block.number;
      entityNodeCount[msg.sender] = entityNodeCount[msg.sender] + 1;

      rFee = requestingFeeInWei;
      nFee = nodeifyFeeInWei;
      require(msg.value == rFee, "invalid fee");

      totalNodesCreated = totalNodesCreated + 1;
      payable(feeCollectorAddress).transfer(msg.value);
      nodeifyToken.transferFrom(msg.sender, address(this), nFee);
      nodeifyToken.transfer(feeCollectorAddress, nFee);

      emit Created(msg.sender, id, block.number, entityNodePaidOnBlock[id] + recurringPaymentCycleInBlocks);
  }

  function claimAll() public payable {
    uint256 value = msg.value;
    for (uint16 i = 1; i <= entityNodeCount[msg.sender]; i++) {
      uint256 reward = getRewardByBlock(msg.sender, i);
      uint256 fee = (reward * claimingFeeNumerator) / claimingFeeDenominator;
      require(value >= fee, "invalid fee");
      if (reward > 0) {
        require(this.claim{value : fee}(i, block.number), "claim failed");
      }
      value = value - fee;
    }
  }

  modifier onlyOwner {
    require(msg.sender == admin, "Not Owner");
    _;
  }

  function updateNaasRequestingFee(uint256 feeInWei) public onlyOwner {
    requestingFeeInWei = feeInWei;
  }

  function updateNaasNodeifyFee(uint256 feeInWei) public onlyOwner {
    nodeifyFeeInWei = feeInWei;
  }

  function updateClaimingFee(uint256 numerator, uint256 denominator) public onlyOwner {
    require(denominator != 0, "Claiming fee required");
    claimingFeeNumerator = numerator;
    claimingFeeDenominator = denominator;
  }

  function updateRecurringFee(uint256 feeInWei) public onlyOwner {
    recurringFeeInWei = feeInWei;
  }

  function updateRecurringPaymentCycleInBlocks(uint256 blocks) public onlyOwner {
    require(blocks > 0, "Period Blocks Must be above 0");
    recurringPaymentCycleInBlocks = blocks;
  }

  function updateGracePeriodInBlocks(uint256 blocks) public onlyOwner {
    require(blocks > 0, "Period Blocks Must be above 0");
    gracePeriodInBlocks = blocks;
  }

  modifier nonNillValue(uint256 _amount) {
    require(_amount > 0, "Not Nill Value");
    _;
  }

  function deposit(uint256 amount) public onlyOwner nonNillValue(amount) {
    nodeifyToken.transferFrom(msg.sender, address(this), amount);
    rewardBalance = rewardBalance + amount;
  }

  function withdraw(address destination, uint256 amount) public onlyOwner nonNillValue(amount) {
    require(rewardBalance >= amount, "not enough");
    rewardBalance = rewardBalance - amount;
    nodeifyToken.transfer(destination, amount);
  }

  function claim(uint128 nodeId, uint256 blockNumber) public payable returns (bool) {
    address sender = msg.sender;
    bytes memory id = getNodeId(sender, nodeId);

    uint256 blockLastClaimedOn = entityNodeClaimedOnBlock[id] != 0 ? entityNodeClaimedOnBlock[id] : entityNodeClaimedOnBlock[id];
    uint256 blockLastPaidOn = entityNodePaidOnBlock[id];

    require(blockLastClaimedOn != 0, "never claimed");
    require(blockNumber <= block.number, "invalid block");
    require(blockNumber > blockLastClaimedOn, "too soon");
    require(blockNumber < blockLastPaidOn + recurringPaymentCycleInBlocks, "pay fee");
    
    uint256 reward = getRewardByBlock(sender, nodeId);
    require(reward > 0, "no reward");

    uint256 fee = (reward * claimingFeeNumerator) / claimingFeeDenominator;
    require(msg.value >= fee, "invalid fee");
    
    rewardBalance = rewardBalance - reward;
    entityNodeClaimedOnBlock[id] = blockNumber;

    payable(feeCollectorAddress).transfer(msg.value);
    nodeifyToken.transfer(sender, reward);
  
    emit Claimed(sender, reward);

    return true;
  }

  function canBePaid(address entity, uint128 nodeId) public view returns (bool) {
    return !hasNodeExpired(entity, nodeId) && !hasMaxPayments(entity, nodeId);
  }

  function getNodeId(address entity, uint128 nodeId) public view returns (bytes memory) {
    uint128 id = nodeId != 0 ? nodeId : entityNodeCount[entity] + 1;
    return abi.encodePacked(entity, id);
  }

  function doesNodeExist(address entity, uint128 nodeId) public view returns (bool) {
    bytes memory id = getNodeId(entity, nodeId);
    return entityNodePaidOnBlock[id] > 0;
  }

  function hasNodeExpired(address entity, uint128 nodeId) public view returns (bool) {
    bytes memory id = getNodeId(entity, nodeId);
    uint256 blockLastPaidOn = entityNodePaidOnBlock[id];

    if (doesNodeExist(entity, nodeId) == false) return true;

    return block.number > blockLastPaidOn + recurringPaymentCycleInBlocks + gracePeriodInBlocks;
  }

  function hasMaxPayments(address entity, uint128 nodeId) public view returns (bool) {
    bytes memory id = getNodeId(entity, nodeId);
    uint256 blockLastPaidOn = entityNodePaidOnBlock[id];
    uint256 limit = (block.number + recurringPaymentCycleInBlocks) * maxPaymentPeriods;

    return blockLastPaidOn + recurringPaymentCycleInBlocks >= limit;
  }

  function payAll(uint256 nodeCount) public payable {
    require(nodeCount > 0, "invalid value");
    require(msg.value == recurringFeeInWei * nodeCount, "invalid fee");

    for (uint16 nodeId = 1; nodeId <= entityNodeCount[msg.sender]; nodeId++) {
      if (!canBePaid(msg.sender, nodeId)) {
        continue;
      }

      this.payFee{value : recurringFeeInWei}(nodeId);
      nodeCount = nodeCount - 1;
    }

    require(nodeCount == 0, "invalid count");
  }

  function payFee(uint128 nodeId) public payable {
    address sender = msg.sender;
    bytes memory id = getNodeId(sender, nodeId);

    require(doesNodeExist(sender, nodeId), "doesnt exist");
    require(hasNodeExpired(sender, nodeId) == false, "too late");
    require(hasMaxPayments(sender, nodeId) == false, "too soon");
    require(msg.value == recurringFeeInWei, "invalid fee");

    entityNodePaidOnBlock[id] = entityNodePaidOnBlock[id] + recurringPaymentCycleInBlocks;
    payable(feeCollectorAddress).transfer(msg.value);

    emit Paid(sender, nodeId, entityNodePaidOnBlock[id]);
  }

  function getReward(address entity, uint128 nodeId) public view returns (uint256) {
    return getRewardByBlock(entity, nodeId);
  }

  function getRewardAll(address entity) public view returns (uint256) {
    uint256 rewardsAll = 0;

    for (uint128 i = 1; i <= entityNodeCount[entity]; i++) {
      rewardsAll = rewardsAll + getRewardByBlock(entity, i);
    }

    return rewardsAll;
  }

  function getRewardByBlock(address entity, uint128 nodeId) public view returns (uint256) {
    bytes memory id = getNodeId(entity, nodeId);

    uint256 blockLastClaimedOn = entityNodeClaimedOnBlock[id] != 0 ? entityNodeClaimedOnBlock[id] : entityNodePaidOnBlock[id];
    // TODO add many checks here to ensure the reward is correct
    if (hasNodeExpired(entity, nodeId)) return 0;
    if (block.number < blockLastClaimedOn) return 0;

    uint256 reward = (block.number - blockLastClaimedOn) * rewardPerBlock;
    return reward;
  }

  function blacklistMalicious(address account, bool value)
      external
      onlyOwner
  {
      _isBlacklisted[account] = value;
  }

}