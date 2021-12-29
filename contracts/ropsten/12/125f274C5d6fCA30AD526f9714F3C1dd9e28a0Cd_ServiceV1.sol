//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IterableMapping.sol";

contract ServiceV1 {
  event Claimed(address indexed entity, uint256 reward);
  event Paid(address indexed entity, uint128 nodeId, uint256 upToBlockNumber);
  event Created(address indexed entity, string nodeName, uint256 blockNumber, uint256 nodeNumber);

  using IterableMapping for IterableMapping.Map;

  struct NodeEntity {
      string name;
      uint256 creationBlockNumber;
      uint256 lastClaimBlockNumber;
      uint256 lastPaidBlockNumber;
  }
  
  mapping(address => NodeEntity[]) public _nodesOfUser; // TODO change to private
  mapping(address => bool) public _isBlacklisted;

  IterableMapping.Map private nodeOwners;

  IERC20 public nodeifyToken;
  address public admin = 0xE5CaB58b538CC570388bF8550B5Ecb71A824EFB4;
  address public feeCollectorAddress = 0x0788a572c51802eEF7d198afaD100627B59e9DEC;
  uint128 public maxNodesPerAddress = 100;
  uint256 public nodePrice = 100000000000000000000;
  uint256 public totalNodesCreated;
  uint128 public rewardPerBlock = 10000000000000;
  uint128 public maxPaymentPeriods = 3;
  uint256 public rewardBalance;
  uint256 public gracePeriodInBlocks = 70000;
  uint256 public recurringPaymentCycleInBlocks = 210000;

  constructor(address _nodeifyTokenAddress) {
    nodeifyToken = IERC20(_nodeifyTokenAddress);
  }

    function createNodeWithTokens(string memory name) public {
        require(
            bytes(name).length > 3 && bytes(name).length < 32,
            "Name Size Invalid"
        );
        address sender = msg.sender;
        require(
            sender != address(0),
            "Creation from the zero address"
        );
        require(!_isBlacklisted[sender], "Blacklisted address");
        require(
            nodeifyToken.balanceOf(sender) >= nodePrice,
            "Balance too low for creation"
        );

        nodeifyToken.transferFrom(sender, address(this), nodePrice);
        createNode(sender, name);
    }

  function claimAll(uint256 blockNumber) public payable {
    uint256 value = msg.value;
    for (uint16 i = 0; i < _nodesOfUser[msg.sender].length; i++) {
      uint256 reward = getRewardByBlock(msg.sender, i, blockNumber);
      uint256 fee = (reward * 3) / 50;
      require(value >= fee, "invalid fee");
      if (reward > 0) {
        claim(msg.sender, i, blockNumber);
      }
      value = value - fee;
    }
  }

  modifier onlyOwner {
    require(msg.sender == admin, "Not Owner");
    _;
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

  function claim(address entity, uint128 nodeId, uint256 blockNumber) public payable returns (bool) {
    uint256 blockLastClaimedOn = _nodesOfUser[entity][nodeId].lastClaimBlockNumber;

    // TODO add more checks here
    require(blockNumber <= block.number, "invalid block");
    require(blockNumber > blockLastClaimedOn, "too soon");

    uint256 reward = getRewardByBlock(msg.sender, nodeId, blockNumber);
    require(reward > 0, "no reward");

    uint256 fee = reward * 3 / 50;
    require(msg.value >= fee, "invalid fee");

    _nodesOfUser[entity][nodeId].lastClaimBlockNumber = blockNumber;

    rewardBalance = rewardBalance - reward;
    payable(feeCollectorAddress).transfer(msg.value);
    nodeifyToken.transfer(msg.sender, reward);

    emit Claimed(msg.sender, reward);

    return true;
  }

  function canBePaid(address entity, uint128 nodeId) public view returns (bool) {
    return !hasNodeExpired(entity, nodeId) && !hasMaxPayments(entity, nodeId);
  }

  function doesNodeExist(address entity, uint128 nodeId) public view returns (bool) {
    return _nodesOfUser[entity][nodeId].lastPaidBlockNumber > 0;
  }

  function hasMaxNodes(address entity) public view returns (bool) {
     return _nodesOfUser[entity].length >= maxNodesPerAddress;
  }

  function hasNodeExpired(address entity, uint128 nodeId) public view returns (bool) {
    uint256 blockLastPaidOn = _nodesOfUser[entity][nodeId].lastPaidBlockNumber;
    if (doesNodeExist(entity, nodeId) == false) return true;

    return block.number > blockLastPaidOn + recurringPaymentCycleInBlocks + gracePeriodInBlocks;
  }

  function hasMaxPayments(address entity, uint128 nodeId) public view returns (bool) {
    uint256 blockLastPaidOn = _nodesOfUser[entity][nodeId].lastPaidBlockNumber;
    uint256 limit = block.number + recurringPaymentCycleInBlocks * maxPaymentPeriods;

    return blockLastPaidOn + recurringPaymentCycleInBlocks >= limit;
  }

  function payAll(uint256 nodeCount) public payable {
    require(nodeCount > 0, "invalid value");
    require(msg.value == 2929616229135700 * nodeCount, "invalid fee");

    for (uint16 nodeId = 0; nodeId < _nodesOfUser[msg.sender].length; nodeId++) {
      if (!canBePaid(msg.sender, nodeId)) {
        continue;
      }

      payFee(nodeId);
      nodeCount = nodeCount - 1;
    }

    require(nodeCount == 0, "invalid count");
  }

  function payFee(uint128 nodeId) public payable {
    address sender = msg.sender;

    require(doesNodeExist(sender, nodeId), "doesnt exist");
    require(hasNodeExpired(sender, nodeId) == false, "too late");
    require(hasMaxPayments(sender, nodeId) == false, "too soon");
    require(msg.value == 2929616229135700, "invalid fee");

    _nodesOfUser[sender][nodeId].lastPaidBlockNumber = block.number;
    payable(feeCollectorAddress).transfer(msg.value);

    emit Paid(sender, nodeId, _nodesOfUser[sender][nodeId].lastPaidBlockNumber + recurringPaymentCycleInBlocks);
  }

    function createNode(address entity, string memory nodeName) internal {
        require(
            isNameAvailable(entity, nodeName),
            "CREATE NODE: Name not available"
        );
        require(
            !hasMaxNodes(entity),
            "CREATE NODE: Max Nodes Reached"
        );
        _nodesOfUser[entity].push(
            NodeEntity({
                name: nodeName,
                creationBlockNumber: block.number,
                lastClaimBlockNumber: block.number,
                lastPaidBlockNumber: block.number
            })
        );
        nodeOwners.set(entity, _nodesOfUser[entity].length);
        totalNodesCreated++;
        emit Created(entity, nodeName, block.number, _nodesOfUser[entity].length);
    }

    function isNameAvailable(address account, string memory nodeName)
        private
        view
        returns (bool)
    {
        NodeEntity[] memory nodes = _nodesOfUser[account];
        for (uint256 i = 0; i < nodes.length; i++) {
            if (keccak256(bytes(nodes[i].name)) == keccak256(bytes(nodeName))) {
                return false;
            }
        }
        return true;
    }

  function getReward(address entity, uint128 nodeId) public view returns (uint256) {
    return getRewardByBlock(entity, nodeId, block.number);
  }
 
  function getNodesPerEntity() public view returns (NodeEntity[] memory){
    return _nodesOfUser[msg.sender];
  }

  function getRewardAll(address entity, uint256 blockNumber) public view returns (uint256) {
    uint256 rewardsAll;

    for (uint128 i = 0; i < _nodesOfUser[entity].length; i++) {
      rewardsAll = rewardsAll + getRewardByBlock(entity, i, blockNumber > 0 ? blockNumber : block.number);
    }

    return rewardsAll;
  }

  function getRewardByBlock(address entity, uint128 nodeId, uint256 blockNumber) public view returns (uint256) {
    uint256 blockLastClaimedOn = _nodesOfUser[entity][nodeId].lastClaimBlockNumber;
    // TODO add many checks here to ensure the reward is correct
    if (hasNodeExpired(entity, nodeId)) return 0;
    if (blockNumber > block.number) return 0;
    if (blockLastClaimedOn == 0) return 0;
    if (blockNumber < blockLastClaimedOn) return 0;

    uint256 reward = (blockNumber - blockLastClaimedOn) * rewardPerBlock;
    return reward;
  }

    function blacklistMalicious(address account, bool value)
        external
        onlyOwner
    {
        _isBlacklisted[account] = value;
    }

}