// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PledgeBase.sol";

/**
 * The Pledge contract allows users to pledge ERC20 tokens to a purpose.
 * The pledged amounts remain at the possession of this contract.
 * Users can unpledge at any moment. Unpledged amounts remain locked for a period of time.
 * Users can withdraw amounts that have been unpledged and whose locking periods have elapsed.
 *
 * The Pledge contract has 3 parameters:
 *     - its `purpose`
 *     - the `lockingPeriod`
 *     - the ERC20 contract of the tokens that can be pledged
 *
 * These parameters are set when the Pledge contract is deployed and are immutable.
 *
 * The frontend should allow users to choose the parameters and deploy an instance of this contract.
 * The frontend should list all instances that have been deployed, their parameters and the `totalPledgeAmount` for each instance.
 * The frontend should allow the list of instances to be filtered by token contract and by purpose, and ordered by `totalPledgeAmount`.
 * The frontend should allow the user to connect his/her metamask wallet and:
 *     - call the `pledge`, `unpledge` and `withdraw` functions;
 *     - show the user's `pledged` balance and `lockedWithdrawalMap` balances.
 *
 */
contract Pledge is PledgeBase, ReentrancyGuard {
  using SafeERC20 for IERC20;

  mapping(address => uint256) public pledged;
  uint256 public totalPledgeAmount;
  uint256 public totalPledgeAddress;

  struct LockedWithdrawal {
    uint256 amount;
    uint256 unlockingTime;
    bool isWithdrawalDone;
  }

  mapping(address => mapping(uint256 => LockedWithdrawal))
    public lockedWithdrawalMap;

  // How many withdrawals per address
  mapping(address => uint256) public lockedWithdrawalCount;

  IERC20 public immutable tokenContract;
  uint256 public lockingPeriod;
  string public purpose;

  event EventPledge(address sender, uint256 amount);
  event EventUnpledge(address sender, uint256 amount);
  event EventWithdraw(address sender, uint256 amount);

  constructor(
    address _tokenContractAddress,
    uint256 _lockingPeriod, // in seconds
    string memory _purpose
  ) {
    tokenContract = IERC20(_tokenContractAddress);
    lockingPeriod = _lockingPeriod;
    purpose = _purpose;
  }

  function pledge(uint256 amount) external whenNotPaused nonReentrant {
    require(amount > 0, "Pledge: invalid amount");
    require(
      tokenContract.allowance(_msgSender(), address(this)) >= amount,
      "Pledge: not enough allowance"
    );

    tokenContract.safeTransferFrom(_msgSender(), address(this), amount);

    pledged[_msgSender()] += amount;
    totalPledgeAmount += amount;
    totalPledgeAddress++;

    emit EventPledge(_msgSender(), amount);
  }

  function unpledge(uint256 amount) external whenNotPaused nonReentrant {
    require(amount > 0, "Pledge: invalid amount");
    require(amount <= pledged[_msgSender()], "Pledge: amount exceeds pledged");

    pledged[_msgSender()] -= amount;
    totalPledgeAmount -= amount;
    if (pledged[_msgSender()] == 0) {
      totalPledgeAddress--;
    }

    uint256 lockedWithdrawalCnt = lockedWithdrawalCount[_msgSender()];
    lockedWithdrawalMap[_msgSender()][lockedWithdrawalCnt] = LockedWithdrawal({
      amount: amount,
      unlockingTime: block.timestamp + lockingPeriod,
      isWithdrawalDone: false
    });
    lockedWithdrawalCount[_msgSender()]++;

    emit EventUnpledge(_msgSender(), amount);
  }

  function withdraw() external whenNotPaused nonReentrant {
    uint256 lockedWithdrawalCnt = lockedWithdrawalCount[_msgSender()];
    require(lockedWithdrawalCnt > 0, "Pledge: no withdrawal available");

    uint256 totalWithdrawAmount = 0;

    for (uint256 i = 0; i < lockedWithdrawalCnt; i++) {
      uint256 unlockingTime =
        lockedWithdrawalMap[_msgSender()][i].unlockingTime;

      uint256 amount = lockedWithdrawalMap[_msgSender()][i].amount;

      bool isWithdrawalDone =
        lockedWithdrawalMap[_msgSender()][i].isWithdrawalDone;

      // Can withdraw
      if (
        isWithdrawalDone == false &&
        block.timestamp >= unlockingTime &&
        amount > 0
      ) {
        totalWithdrawAmount += amount;
        lockedWithdrawalMap[_msgSender()][i].isWithdrawalDone = true;
        tokenContract.safeTransfer(_msgSender(), amount);
      }
    }

    require(totalWithdrawAmount > 0, "Pledge: withdrawal still locked");

    emit EventWithdraw(_msgSender(), totalWithdrawAmount);
  }

  function setLockingPeriod(uint256 _lockingPeriod) external isAuthorized {
    require(_lockingPeriod > 0, "Pledge: invalid _lockingPeriod");
    require(
      _lockingPeriod < lockingPeriod,
      "Pledge: can only decrease the lockingPeriod"
    );

    lockingPeriod = _lockingPeriod;
  }
}