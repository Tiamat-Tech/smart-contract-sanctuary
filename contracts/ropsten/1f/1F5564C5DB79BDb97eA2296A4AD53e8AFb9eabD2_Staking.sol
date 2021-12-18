// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMathInt, SafeMathUint} from "./libraries/SafeMath.sol";

contract Staking is Ownable {
    using SafeMathUint for uint256;
    using SafeMathInt for int256;

    uint256 internal constant MAGNITUDE = 10**40;

    // Token token;
    uint256 internal magnifiedRewardPerShare;
    uint256 internal _totalSupply;
    mapping(address => uint256) public claimedRewards;

    event RewardsReceived(address indexed from, uint256 amount);
    event Deposit(address indexed user, uint256 underlyingToken);
    event Withdraw(address indexed user, uint256 underlyingToken);
    event RewardClaimed(address indexed user, address indexed to, uint256 amount);

    /// @notice when the smart contract receives ETH, register payment
    /// @dev can only receive ETH when tokens are staked
    receive() external payable {
        require(totalSupply() > 0, "NO_TOKENS_STAKED");
        if (msg.value > 0) {
            magnifiedRewardPerShare += (msg.value * MAGNITUDE) / totalSupply();
            emit RewardsReceived(msg.sender, msg.value);
        }
    }

    /// @notice allows to deposit the underlying token into the staking contract
    /// @dev mints an amount of overlying tokens according to the stake in the pool
    /// @param _amount amount of underlying token to deposit
    function deposit(address sender, uint256 _amount) external onlyOwner {
        _totalSupply += _amount;
        magnifiedRewardPerShare = (address(this).balance * MAGNITUDE) / totalSupply();
        emit Deposit(sender, _amount);
    }

    /// @notice allows to withdraw the underlying token from the staking contract
    /// @param _amount of overlying tokens to withdraw
    /// @param _claim whether or not to claim ETH rewards
    /// @return amount of underlying tokens withdrawn
    function withdraw(address sender, uint256 _amount, bool _claim) external onlyOwner returns (uint256) {
        if (_claim) {
            uint256 claimableRewards = claimableRewardsOf(sender, _amount);
            if (claimableRewards > 0) {
                claimedRewards[sender] += claimableRewards;
                (bool success, ) = sender.call{value: claimableRewards}("");
                require(success, "ETH_TRANSFER_FAILED");
                emit RewardClaimed(sender, sender, claimableRewards);
            }
        }
        _totalSupply -= _amount;
        magnifiedRewardPerShare = (address(this).balance * MAGNITUDE) / totalSupply();
        emit Withdraw(sender, _amount);
        return _amount;
    }

    /// @notice allows to claim accumulated ETH rewards
    /// @param _to address to send rewards to
    function claimRewards(address sender, address _to, uint256 userAmount) external onlyOwner {
        uint256 claimableRewards = claimableRewardsOf(sender, userAmount);
        if (claimableRewards > 0) {
            claimedRewards[sender] += claimableRewards;
            (bool success, ) = _to.call{value: claimableRewards}("");
            magnifiedRewardPerShare -= (claimableRewards * MAGNITUDE) / totalSupply();
            require(success, "ETH_TRANSFER_FAILED");
            emit RewardClaimed(sender, _to, claimableRewards);
        }
    }

    /// @return total amount of ETH rewards earned by user
    function totalRewardsEarned(uint256 userAmount) public view returns (uint256) {
        int256 magnifiedRewards = (magnifiedRewardPerShare * userAmount).toInt256Safe();
        // uint256 correctedRewards = (magnifiedRewards + magnifiedRewardCorrections[_user]).toUint256Safe();
        return magnifiedRewards.toUint256Safe() / MAGNITUDE;
    }

    /// @return amount of ETH rewards that can be claimed by user
    function claimableRewardsOf(address _user, uint256 userAmount) public view returns (uint256) {
        return totalRewardsEarned(userAmount) - claimedRewards[_user];
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
}