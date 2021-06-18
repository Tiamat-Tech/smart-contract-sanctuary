// SPDX-License-Identifier: MIT
pragma solidity =0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


// TODO add arbitrary code execution from voting
// TODO remove refunding and fundedByAddress
contract Roadmap is Initializable, AccessControl {
  using SafeERC20 for IERC20;
  // Because we aren't using short time durations for milestones it's safe to compare with block.timestamp in our case
  // solhint-disable not-rely-on-time

  bytes32 public constant ROLE_ADMIN = keccak256("ROLE_ADMIN");

  enum FundsReleaseType {
    MilestoneStart,
    MilestoneFinish,
    MilestoneStartDate,
    MilestoneEndDate
  }
  enum State { Refunding, Funding }
  enum VotingStatus { Planned, Started, Finished, Aborted }

  struct Milestone {
    uint256 amount;
    uint256 startEndDates;
    VotingStatus votingStatus;
    uint256 withdrawnAmount;
    bool isCreated;
  }

  uint256 public id;
  uint256 public totalFunded;
  IERC20 public funds;
  address public voting;
  address public refunding;
  FundsReleaseType public fundsReleaseType;
  State public state;
  mapping(uint256 => Milestone) public milestones;
  mapping(address => uint256) public fundedByAddress;

  event Funded(address indexed sender, uint256 amount);
  event Refunded(address indexed sender, uint256 amount);
  event Withdrawn(uint256 indexed id, address recipient, uint256 amount);
  event RefundingContractChanged(address refunding);
  event VotingContractChanged(address voting);
  event MilestoneAdded(
    uint256 indexed id,
    uint256 amount,
    uint256 startEndDates
  );
  event MilestoneUpdated(
    uint256 indexed id,
    uint256 amount,
    uint256 startEndDates
  );
  event MilestoneRemoved(uint256 indexed id);
  event MilestoneVotingStatusUpdated(
    uint256 indexed id,
    VotingStatus votingStatus
  );

  modifier onlyVoter() {
    require(msg.sender == voting, "Caller is not voting contract");
    _;
  }

  modifier inState(State _state) {
    require(state == _state, "State do not match");
    _;
  }

  function initialize(
    uint256 _id,
    IERC20 _funds,
    address _voting,
    address _refunding,
    FundsReleaseType _fundsReleaseType,
    address _admin,
    uint256[] memory _milestonesIds,
    uint256[] memory _milestonesAmounts,
    uint256[] memory _milestonesDates
  ) external initializer {
    _setupRole(ROLE_ADMIN, _admin);
    _setupRole(ROLE_ADMIN, _voting);
    _setRoleAdmin(ROLE_ADMIN, ROLE_ADMIN);

    id = _id;
    funds = _funds;
    voting = _voting;
    refunding = _refunding;
    fundsReleaseType = _fundsReleaseType;
    state = State.Funding;

    addMilestonesInternal(_milestonesIds, _milestonesAmounts, _milestonesDates);
  }

  function fundRoadmap(uint256 _funds) external inState(State.Funding) {
    funds.safeTransferFrom(msg.sender, address(this), _funds);
    totalFunded = totalFunded + _funds;
    fundedByAddress[msg.sender] = fundedByAddress[msg.sender] + _funds;
    emit Funded(msg.sender, _funds);
  }

  function withdraw(
    uint256 _id,
    address _recipient,
    uint256 _funds
  ) external inState(State.Funding) onlyRole(ROLE_ADMIN) {
    require(
      checkIsMilestoneWithdrawable(_id),
      "Cannot withdraw if voting status is not correct"
    );
    require(
      funds.balanceOf(address(this)) >= _funds,
      "Cannot withdraw more than contract balance"
    );
    require(
      milestones[_id].amount - milestones[_id].withdrawnAmount >= _funds,
      "Cannot withdraw more than milestone available funds"
    );

    milestones[_id].withdrawnAmount = milestones[_id].withdrawnAmount + _funds;
    funds.safeTransfer(_recipient, _funds);
    emit Withdrawn(_id, _recipient, _funds);
  }

  function setRefundingContract(address _refunding)
    external
    onlyVoter
    inState(State.Funding)
  {
    require(_refunding != address(0), "Cannot set zero address");
    refunding = _refunding;
    emit RefundingContractChanged(_refunding);
  }

  function setVotingContract(address _voting)
    external
    onlyVoter
    inState(State.Funding)
  {
    require(_voting != address(0), "Cannot set zero address");
    grantRole(ROLE_ADMIN, _voting);
    renounceRole(ROLE_ADMIN, voting);
    voting = _voting;
    emit VotingContractChanged(_voting);
  }

  function addMilestone(
    uint256 _id,
    uint256 _amount,
    uint256 _startEndDates
  ) external onlyVoter inState(State.Funding) {
    addMilestoneInternal(_id, _amount, _startEndDates);
  }

  function addMilestones(
    uint256[] memory _ids,
    uint256[] memory _amounts,
    uint256[] memory _startEndDates
  ) external onlyVoter inState(State.Funding) {
    addMilestonesInternal(_ids, _amounts, _startEndDates);
  }

  function updateMilestone(
    uint256 _id,
    uint256 _amount,
    uint256 _startEndDates
  ) external onlyVoter inState(State.Funding) {
    require(doesMilestoneExist(_id), "Milestone doesn't exists");
    require(
      _amount >= milestones[_id].withdrawnAmount,
      "Cannot set amount less than withdrawn amount"
    );

    milestones[_id].amount = _amount;
    milestones[_id].startEndDates = _startEndDates;
    emit MilestoneUpdated(_id, _amount, _startEndDates);
  }

  function removeMilestone(uint256 _id)
    external
    onlyVoter
    inState(State.Funding)
  {
    require(
      milestones[_id].votingStatus == VotingStatus.Planned,
      "Cannot remove milestone if status is not planned"
    );
    require(
      milestones[_id].withdrawnAmount == 0,
      "Withdrawn amount is more than 0"
    );
    delete milestones[_id];
    emit MilestoneRemoved(_id);
  }

  function updateMilestoneVotingStatus(uint256 _id, VotingStatus _votingStatus)
    external
    onlyVoter
    inState(State.Funding)
  {
    milestones[_id].votingStatus = _votingStatus;
    emit MilestoneVotingStatusUpdated(_id, _votingStatus);
  }

  function updateRoadmapState(State _state)
    external
    onlyVoter
    inState(State.Funding)
  {
    if (_state == State.Refunding) {
      state = _state;
      uint256 balance = funds.balanceOf(address(this));
      refund(balance);
    }
  }

  function checkIsMilestoneWithdrawable(uint256 _id)
    public
    view
    returns (bool)
  {
    uint256 startDate;
    uint256 endDate;
    VotingStatus votingStatus = milestones[_id].votingStatus;

    (startDate, endDate) = unpackDates(milestones[_id].startEndDates);

    if (fundsReleaseType == FundsReleaseType.MilestoneStart) {
      return (votingStatus == VotingStatus.Started ||
        votingStatus == VotingStatus.Finished);
    } else if (fundsReleaseType == FundsReleaseType.MilestoneFinish) {
      return (votingStatus == VotingStatus.Finished);
    } else if (fundsReleaseType == FundsReleaseType.MilestoneStartDate) {
      return (isMilestoneScheduled(_id) && startDate <= block.timestamp);
    } else if (fundsReleaseType == FundsReleaseType.MilestoneEndDate) {
      return (isMilestoneScheduled(_id) && endDate <= block.timestamp);
    }

    return false;
  }

  function isMilestoneScheduled(uint256 _id) public view returns (bool) {
    Milestone storage milestone = milestones[_id];
    return milestone.isCreated && milestone.startEndDates != 0;
  }

  function packDates(uint128 _startDate, uint128 _endDate)
    external
    pure
    returns (uint256)
  {
    return (uint256(_startDate) << 128) | uint128(_endDate);
  }

  function unpackDates(uint256 _packDate)
    public
    pure
    returns (uint128 a, uint128 b)
  {
    return (uint128(_packDate >> 128), uint128(_packDate));
  }

  function refund(uint256 _funds) private inState(State.Refunding) {
    funds.safeTransfer(refunding, _funds);
    emit Refunded(msg.sender, _funds);
  }

  function addMilestonesInternal(
    uint256[] memory _ids,
    uint256[] memory _amounts,
    uint256[] memory _startEndDates
  ) internal {
    require(
      _ids.length == _amounts.length && _ids.length == _startEndDates.length,
      "Arrays must be the same length"
    );

    for (uint256 i = 0; i < _ids.length; i++) {
      addMilestoneInternal(_ids[i], _amounts[i], _startEndDates[i]);
    }
  }

  function addMilestoneInternal(
    uint256 _id,
    uint256 _amount,
    uint256 _startEndDates
  ) internal {
    require(!doesMilestoneExist(_id), "Milestone already exists");

    milestones[_id].amount = _amount;
    milestones[_id].startEndDates = _startEndDates;
    milestones[_id].votingStatus = VotingStatus.Planned;
    milestones[_id].isCreated = true;
    emit MilestoneAdded(_id, _amount, _startEndDates);
  }

  function doesMilestoneExist(uint256 _id) private view returns (bool) {
    return milestones[_id].isCreated;
  }
}