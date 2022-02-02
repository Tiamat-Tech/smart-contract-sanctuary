//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EthPoolRecurring is Ownable {
    uint16 public nextRewardId = 1;
    uint16[] public rewardIds;
    mapping(uint16 => uint32) public rewardAmounts;

    struct Deposit {
        uint32 amount;
        uint16 nextRewardId;
    }

    mapping(address => Deposit[]) public deposits;
    mapping(uint16 => uint32) public totalDepositsAgainstReward;

    function addReward(uint32 _rewardAmount) public payable onlyOwner {
        require(_rewardAmount > 0, "Reward cannot be 0");
        require(msg.value == _rewardAmount, "Paid amount not same as passed");

        rewardIds.push(nextRewardId);
        rewardAmounts[nextRewardId] = _rewardAmount;
        totalDepositsAgainstReward[
            nextRewardId + 1
        ] = totalDepositsAgainstReward[nextRewardId];

        nextRewardId++;
    }

    function deposit(uint32 _amount) public payable {
        require(_amount > 0, "Amount cannot be 0");
        require(msg.value == _amount, "Paid amount not same as passed");

        deposits[msg.sender].push(
            Deposit({amount: _amount, nextRewardId: nextRewardId})
        );
        totalDepositsAgainstReward[nextRewardId] += _amount;
    }

    function withdraw() public {
        uint32 total;

        uint32 totalDepositFromUser = 0;

        for (uint16 i = 0; i < deposits[msg.sender].length; i++) {
            Deposit memory userDeposit = deposits[msg.sender][i];
            total += userDeposit.amount;
            totalDepositFromUser += userDeposit.amount;

            // Reward = (total deposit made the user so far) / (total made by all users againt the reward) * reward amount
            if (rewardAmounts[userDeposit.nextRewardId] != 0) {
                total +=
                    (rewardAmounts[userDeposit.nextRewardId] *
                        totalDepositFromUser) /
                    totalDepositsAgainstReward[userDeposit.nextRewardId];
            }

            // users balance should not be counted for next reward total
            // they are carried forward when a znew reward is creatd
            totalDepositsAgainstReward[nextRewardId] -= userDeposit.amount;
        }

        delete deposits[msg.sender];

        (bool suucess, ) = msg.sender.call{value: total}("");
        require(suucess, "Failed to send Ether");
    }
}