//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ERC20/ERC20.sol";
import "./interfaces/IERC2917.sol";
import "../../libraries/Upgradable.sol";
import "../../libraries/SafeMath.sol";
import "../../libraries/ReentrancyGuard.sol";

contract ERC2917 is
    IERC2917,
    ERC20,
    UpgradableProduct,
    UpgradableGovernance,
    ReentrancyGuard
{
    using SafeMath for uint256;

    uint256 public mintCumulation;
    uint256 public usdPerBlock;
    uint256 public lastRewardBlock;
    uint256 public totalProductivity;
    uint256 public accAmountPerShare;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public users;

    // creation of the interests token.
    constructor(
        string memory name,
        string memory symbol,
        uint256 _interestsRate
    ) ERC20(name, symbol) UpgradableProduct() UpgradableGovernance() {
        usdPerBlock = _interestsRate;
    }

    // function initialize(
    //     uint256 _interestsRate,
    //     string memory _name,
    //     string memory _symbol,
    //     uint8 _decimals,
    //     address _impl,
    //     address _governor
    // ) external {
    //     impl = _impl;
    //     governor = _governor;
    //     name = _name;
    //     symbol = _symbol;
    //     decimals = _decimals;
    //     usdPerBlock = _interestsRate;
    // }

    function increment() public {
        usdPerBlock++;
    }

    function changeInterestRatePerBlock(uint256 value)
        external
        override
        requireGovernor
        returns (bool)
    {
        uint256 old = usdPerBlock;
        require(value != old, "AMOUNT_PER_BLOCK_NO_CHANGE");

        usdPerBlock = value;

        emit InterestRatePerBlockChanged(old, value);
        return true;
    }

    function enter(address account, uint256 amount)
        external
        override
        returns (bool)
    {
        require(this.deposit(account, amount), "INVALID DEPOSIT");
        return increaseProductivity(account, amount);
    }

    function exit(address account, uint256 amount)
        external
        override
        returns (bool)
    {
        require(this.withdrawal(account, amount), "INVALID WITHDRAWAL");
        return decreaseProductivity(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(decreaseProductivity(from, amount), "INVALID DEC PROD");
        require(increaseProductivity(to, amount), "INVALID INC PROD");
    }

    function update() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (totalProductivity == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = block.number.sub(lastRewardBlock);

        uint256 reward = multiplier.mul(usdPerBlock);

        _balances[address(this)] = _balances[address(this)].add(reward);

        _totalSupply = _totalSupply.add(reward);

        accAmountPerShare = accAmountPerShare.add(
            reward.mul(1e12).div(totalProductivity)
        );
        lastRewardBlock = block.number;
    }

    function increaseProductivity(address user, uint256 value)
        internal
        returns (bool)
    {
        require(value > 0, "PRODUCTIVITY_VALUE_MUST_BE_GREATER_THAN_ZERO");

        UserInfo storage userInfo = users[user];
        update();
        if (userInfo.amount > 0) {
            uint256 pending = userInfo
                .amount
                .mul(accAmountPerShare)
                .div(1e12)
                .sub(userInfo.rewardDebt);
            _transfer(address(this), user, pending);
            mintCumulation = mintCumulation.add(pending);
        }

        totalProductivity = totalProductivity.add(value);

        userInfo.amount = userInfo.amount.add(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerShare).div(1e12);
        emit ProductivityIncreased(user, value);
        return true;
    }

    function decreaseProductivity(address user, uint256 value)
        internal
        returns (bool)
    {
        require(value > 0, "INSUFFICIENT_PRODUCTIVITY");

        UserInfo storage userInfo = users[user];
        require(userInfo.amount >= value, "Decrease : FORBIDDEN");
        update();
        uint256 pending = userInfo.amount.mul(accAmountPerShare).div(1e12).sub(
            userInfo.rewardDebt
        );
        _transfer(address(this), user, pending);
        mintCumulation = mintCumulation.add(pending);
        userInfo.amount = userInfo.amount.sub(value);
        userInfo.rewardDebt = userInfo.amount.mul(accAmountPerShare).div(1e12);
        totalProductivity = totalProductivity.sub(value);

        emit ProductivityDecreased(user, value);
        return true;
    }

    function take() external view override returns (uint256) {
        UserInfo storage userInfo = users[msg.sender];
        uint256 _accAmountPerShare = accAmountPerShare;

        if (block.number > lastRewardBlock && totalProductivity != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 reward = multiplier.mul(usdPerBlock);
            _accAmountPerShare = _accAmountPerShare.add(
                reward.mul(1e12).div(totalProductivity)
            );
        }
        return
            userInfo.amount.mul(_accAmountPerShare).div(1e12).sub(
                userInfo.rewardDebt
            );
    }

    function takeWithAddress(address user) external view returns (uint256) {
        UserInfo storage userInfo = users[user];
        uint256 _accAmountPerShare = accAmountPerShare;

        if (block.number > lastRewardBlock && totalProductivity != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 reward = multiplier.mul(usdPerBlock);
            _accAmountPerShare = _accAmountPerShare.add(
                reward.mul(1e12).div(totalProductivity)
            );
        }
        return
            userInfo.amount.mul(_accAmountPerShare).div(1e12).sub(
                userInfo.rewardDebt
            );
    }

    function takeWithBlock() external view override returns (uint256, uint256) {
        UserInfo storage userInfo = users[msg.sender];
        uint256 _accAmountPerShare = accAmountPerShare;
        // uint256 lpSupply = totalProductivity;
        if (block.number > lastRewardBlock && totalProductivity != 0) {
            uint256 multiplier = block.number.sub(lastRewardBlock);
            uint256 reward = multiplier.mul(usdPerBlock);
            _accAmountPerShare = _accAmountPerShare.add(
                reward.mul(1e12).div(totalProductivity)
            );
        }
        return (
            userInfo.amount.mul(_accAmountPerShare).div(1e12).sub(
                userInfo.rewardDebt
            ),
            block.number
        );
    }

    function mint() external override nonReentrant returns (uint256) {
        return 0;
    }

    function getProductivity(address user)
        external
        view
        override
        returns (uint256, uint256)
    {
        return (users[user].amount, totalProductivity);
    }

    function interestsPerBlock() external view override returns (uint256) {
        return accAmountPerShare;
    }

    function getStatus()
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            lastRewardBlock,
            totalProductivity,
            accAmountPerShare,
            mintCumulation
        );
    }
}