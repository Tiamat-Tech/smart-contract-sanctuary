// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./interfaces/IReserve.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Reserve is IReserve, Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IBuyback public override buyback;
    address public override money;
    uint256 public override moneyBalance;
    uint256 public override totalProportions;
    uint256 public override totalMoneyCollected;

    mapping(address => Withdrawer) public override withdrawers;

    event UpdateBuyback(address _buyback);
    event UpdateMoney(address _money);

    modifier onlyBuyback() {
        require(
            msg.sender != address(buyback),
            "Reserve:onlyBuyback:: ERR_ZERO_ADDR"
        );
        _;
    }

    modifier onlyWithdrawers() {
        require(
            withdrawers[msg.sender].isEligible,
            "Reserve:onlyWithdrawers:: ERR_CANNOT_WITHDRAW"
        );
        _;
    }

    constructor(address _money, address _buyback) public {
        require(
            _money != address(0),
            "Reserve:constructor:: ERR_ZERO_ADDRESS_MONEY"
        );
        require(
            _buyback != address(0),
            "Reserve:constructor:: ERR_ZERO_ADDRESS_BUYBACK"
        );

        buyback = IBuyback(_buyback);
        money = _money;
    }

    function updateBuyback(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Reserve:updateBuyback:: ERR_ZERO_ADDRESS"
        );
        buyback = IBuyback(_newAddress);
        emit UpdateBuyback(_newAddress);
    }

    function updateMoney(address _newAddress) external override onlyOwner {
        require(
            _newAddress != address(0),
            "Reserve:updateMoney:: ERR_ZERO_ADDRESS"
        );
        money = _newAddress;
        emit UpdateMoney(_newAddress);
    }

    function addWithdrawers(
        address[] calldata _withdrawers,
        uint256[] calldata _proportions
    ) external onlyOwner {
        for (uint8 index = 0; index < _withdrawers.length; index++) {
            _addWithdrawer(_withdrawers[index], _proportions[index]);
            totalProportions = totalProportions.add(_proportions[index]);
        }
    }

    function _addWithdrawer(address _withdrawer, uint256 _proportion) internal {
        require(
            _withdrawer != address(0),
            "Reserve:_addWithdrawer:: ERR_INVALID_ADDRESS"
        );

        Withdrawer storage _withdrawerDetails = withdrawers[msg.sender];
        _withdrawerDetails.isEligible = true;
        _withdrawerDetails.proportion = _proportion;
    }

    function updateWithdrawer(address _oldWithdrawer, address _newWithdrawer)
        external
        override
        onlyOwner
    {
        require(
            withdrawers[_oldWithdrawer].isEligible &&
                !withdrawers[_newWithdrawer].isEligible,
            "Reserve:updateWithdrawer:: ERR_WITHDRAWER"
        );

        Withdrawer storage oldWithdrawer = withdrawers[_oldWithdrawer];
        Withdrawer storage newWithdrawer = withdrawers[_newWithdrawer];

        oldWithdrawer.isEligible = false;
        newWithdrawer.isEligible = true;

        newWithdrawer.proportion = oldWithdrawer.proportion;
        newWithdrawer.amountWithdrawn = oldWithdrawer.amountWithdrawn;
    }

    function deposit(uint256 _deposit)
        external
        override
        onlyBuyback
        whenNotPaused
    {
        uint256 contractBalance = IERC20(money).balanceOf(address(this));
        require(
            contractBalance >= _deposit + moneyBalance,
            "Reserve:deposit:: ERR_MONEY_NOT_DEPOSITED"
        );

        moneyBalance = moneyBalance.add(contractBalance);
    }

    function canWithdraw() external view override returns (bool) {
        Withdrawer memory details = withdrawers[msg.sender];

        uint256 toWithdraw = (totalMoneyCollected * (details.proportion)) /
            totalProportions;

        if (toWithdraw >= details.amountWithdrawn) return true;
        return false;
    }

    function withdrawRewards()
        external
        payable
        override
        onlyWithdrawers
        whenNotPaused
        returns (uint256 toWithdraw)
    {
        Withdrawer storage details = withdrawers[msg.sender];

        toWithdraw =
            (totalMoneyCollected * (details.proportion)) /
            totalProportions;

        require(
            toWithdraw >= details.amountWithdrawn,
            "Reserve:updateWithdrawer:: ERR_NO_REWARDS"
        );

        details.amountWithdrawn = details.amountWithdrawn + toWithdraw;
        moneyBalance = moneyBalance - toWithdraw;
        IERC20(money).safeTransfer(msg.sender, toWithdraw);
    }
}