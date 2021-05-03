// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC677Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Stake is Ownable, IERC677Receiver {
    using SafeERC20 for IERC20;

    mapping (address => uint) public amounts;
    mapping (address => uint) public rewards;
    IERC20 public stakeToken;
    uint256 public rewardPerBlock;
    uint256 public rewardStartBlock;
    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;

    event Deposit(address indexed user, uint256 indexed amount);
    event Withdraw(address indexed user, uint256 indexed amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed amount);

    constructor(
        IERC20 _stakeToken,
        uint256 _rewardPerBlock,
        uint256 _rewardStartBlock
    ) {
        require(_rewardPerBlock > 1e6, "ctor: reward per block is too small");
        stakeToken = _stakeToken;
        rewardPerBlock = _rewardPerBlock;
        rewardStartBlock = _rewardStartBlock;

        lastRewardBlock = block.number > rewardStartBlock ? block.number : rewardStartBlock;
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) public onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    function calcAccRewardPerShare() public view returns (uint256) {
        if (block.number <= lastRewardBlock) {
            return accRewardPerShare;
        }
        uint256 lpSupply = stakeToken.balanceOf(address(this));
        if (lpSupply == 0) {
            return accRewardPerShare;
        }
        uint256 multiplier = block.number - lastRewardBlock;
        uint256 tokenReward = multiplier * rewardPerBlock;
        if (tokenReward <= 0) {
            return accRewardPerShare;
        }
        return accRewardPerShare + ((tokenReward * 1e12) / lpSupply);
    }

    function balanceOf(address _user) external view returns (uint) {
        return amounts[_user];
    }

    function pendingReward(address _user) external view returns (uint) {
        uint rewardPerShare = calcAccRewardPerShare();
        uint amount = amounts[_user];
        uint reward = rewards[_user];
        uint newReward = (amount * rewardPerShare) / 1e12;
        return newReward > reward ? newReward - reward : 0;
    }

    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        accRewardPerShare = calcAccRewardPerShare();
        lastRewardBlock = block.number;
    }

    function _farm(address _sender) private {
        updatePool();
        uint amount = amounts[_sender];
        uint reward = rewards[_sender];
        uint newReward = (amount * accRewardPerShare) / 1e12;
        if (amount > 0 && newReward > reward) {
            stakeToken.safeTransferFrom(
              owner(), _sender, newReward - reward);
        }
        rewards[_sender] = newReward;
    }

    function farm() public {
      _farm(msg.sender);
    }

    function _deposit(address _sender, uint _amount) private {
        _farm(_sender);
        amounts[_sender] = amounts[_sender] + _amount;
        rewards[_sender] = (amounts[_sender] * accRewardPerShare) / 1e12;
        emit Deposit(_sender, _amount);
    }

    function deposit(uint _amount) public {
      if (_amount > 0) {
        stakeToken.safeTransferFrom(
          address(msg.sender), address(this), _amount);
        _deposit(msg.sender, _amount);
      }
    }

    function onTokenTransfer(address _sender, uint _amount, bytes calldata _data) external override {
      require(msg.sender == address(stakeToken), "onTokenTransfer: only supports stakeToken");
      if (_amount > 0) {
        _deposit(_sender, _amount);
      }
    }

    function withdraw(uint _amount) public {
        uint amount = amounts[msg.sender];
        require(amount >= _amount, "not enough balance");
        _farm(msg.sender);
        if (_amount > 0) {
            amounts[msg.sender] = amount - _amount;
            rewards[msg.sender] = (amounts[msg.sender] * accRewardPerShare) / 1e12;
            stakeToken.safeTransfer(address(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _amount);
    }

    function emergencyWithdraw() public {
        uint amount = amounts[msg.sender];
        amounts[msg.sender] = 0;
        rewards[msg.sender] = 0;
        stakeToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    function extractLostToken(address token, uint amount) public onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }
}