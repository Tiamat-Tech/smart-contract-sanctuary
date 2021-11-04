// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "./token/ERC20/ERC20.sol";
import "./math/SafeMath.sol";
import "./utils/Arrays.sol";
import "./access/Ownable.sol";
import "hardhat/console.sol";

contract ERC20Vested is ERC20, Ownable {
    event Vesting(address indexed recipient, uint256 value, uint256 startDate);

    uint256 constant BASIS_POINT_DIVISOR = 10000;

    struct vesting {
        uint256 amount;
        uint256 startDate;
    }

    /**
     * @dev Since Solidity 0.8.0 reverting on overflow is the default but
     * let's keep SafeMath nevertheless in case someone messes with the compiler version.
     */
    using SafeMath for uint256;

    using Arrays for uint256[];

    uint256[] private _vestingDays;

    uint256[] private _vestingBasisPoints;

    mapping(address => vesting) private _vesting;

    constructor(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256[] memory vestingDays,
        uint256[] memory vestingBasisPoints
    ) payable Ownable() ERC20(name, symbol) {
        require(
            vestingDays.length == vestingBasisPoints.length,
            "ERC20Vested: Date array and basis points array have different lengths."
        );
        _mint(owner(), totalSupply);
        _vestingDays = vestingDays;
        _vestingBasisPoints = vestingBasisPoints;
    }

    function _hasVesting(address account) private view returns (bool) {
        return _vesting[account].amount > 0;
    }

    function transferOwnership(address newOwner)
        public
        virtual
        override
        onlyOwner
    {
        require(
            !_hasVesting(newOwner),
            "ERC20Vested: New owner must not have vesting."
        );
        super.transferOwnership(newOwner);
        transfer(newOwner, balanceOf(_msgSender()));
    }

    function today() public view virtual returns (uint128) {
        return uint128(block.timestamp);
    }

    function transferVested(
        address recipient,
        uint256 amount,
        uint256 startDate
    ) public onlyOwner {
        address owner = owner();
        require(
            recipient != owner,
            "ERC20Vested: Owner must not have vesting."
        );
        require(
            amount > 0,
            "ERC20Vested: Amount vested must be larger than 0."
        );
        require(
            !_hasVesting(recipient),
            "ERC20Vested: Recipient already has vesting."
        );
        _vesting[recipient] = vesting(amount, startDate);
        emit Vesting(recipient, amount, startDate);
        _transfer(owner, recipient, amount);
    }

    function _amountAvailable(address from) internal view returns (uint256) {
        vesting memory vested = _vesting[from];
        uint256 totalBalance = _totalBalanceOf(from);
        if (vested.amount > 0) {
            // vesting applies
            uint256 vestingIndex =
                _vestingDays.findUpperBound(today() - vested.startDate);

            if (vestingIndex < _vestingDays.length) {
                // still in vesting phase
                uint256 vestingBasisPoints = _vestingBasisPoints[vestingIndex];
                uint256 maxAmountAvailable =
                    vested.amount.mul(vestingBasisPoints).div(
                        BASIS_POINT_DIVISOR
                    );
                uint256 remainingVestedAmount =
                    vested.amount.sub(maxAmountAvailable);
                return totalBalance.sub(remainingVestedAmount);
            } else {
                return totalBalance;
            }
        } else {
            return totalBalance;
        }
    }

    function totalBalanceOf(address account) public view returns (uint256) {
        return _totalBalanceOf(account);
    }

    function _totalBalanceOf(address account)
        internal
        view
        virtual
        returns (uint256)
    {
        return super.balanceOf(account);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _amountAvailable(account);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // When minting tokens
            require(
                owner() == _msgSender(),
                "ERC20Vested: Only owner is allowed to mint tokens."
            );
        } else {
            uint256 amountAvailable = _amountAvailable(from);
            require(
                amountAvailable >= amount,
                "ERC20Vested: Amount exceeds amount available"
            );
        }
    }
}