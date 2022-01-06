// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

struct FrozenWallet {
    address wallet;
    uint256 totalAmount;
    uint256 monthlyAmount;
    uint256 initialAmount;
    uint256 startDay;
    uint256 afterDays;
    bool scheduled;
    uint256 monthDelay;
}

struct VestingType {
    uint256 monthlyRate;
    uint256 initialRate;
    uint256 afterDays;
    uint256 monthDelay;
    bool vesting;
}

contract MetToken is
    Initializable,
    OwnableUpgradeable,
    ERC20PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    uint256 constant maxTotalSupply = 500000000000000000000000000;
    uint256 constant releaseTime = 1641481200;

    mapping(address => FrozenWallet) public frozenWallets;
    VestingType[] public vestingTypes;

    uint256 public pausedBeforeBlockNumber;

    function initialize() public initializer {
        __Ownable_init();
        __ERC20_init("MET Token", "MET");
        __ERC20Pausable_init();

        // Mint All TotalSuply in the Account OwnerShip
        _mint(owner(), maxTotalSupply);

        // Mining Pool 25%
        vestingTypes.push(
            VestingType(62500000000000000000000000, 0, 180 days, 0, true)
        ); // 180 Days 50% Percent
    }

    event PausedUntilBlock(uint256 total);

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 z
    ) public pure returns (uint256) {
        return x.mul(y).div(z);
    }

    function addAllocations(
        address[] memory addresses,
        uint256[] memory totalAmounts,
        uint256 vestingTypeIndex
    ) external payable onlyOwner returns (bool) {
        require(
            addresses.length == totalAmounts.length,
            "Address and totalAmounts length must be same"
        );
        require(vestingTypes[vestingTypeIndex].vesting, "invalid opcode");

        VestingType memory vestingType = vestingTypes[vestingTypeIndex];
        uint256 addressesLength = addresses.length;

        for (uint256 i = 0; i < addressesLength; i++) {
            address _address = addresses[i];
            uint256 totalAmount = totalAmounts[i];
            uint256 monthlyAmount = mulDiv(
                totalAmounts[i],
                vestingType.monthlyRate,
                100000000000000000000
            );
            uint256 initialAmount = mulDiv(
                totalAmounts[i],
                vestingType.initialRate,
                100000000000000000000
            );
            uint256 afterDay = vestingType.afterDays;
            uint256 monthDelay = vestingType.monthDelay;

            //Additional checks required by zokyo, address != 0, and totalAmount != 0
            require(
                _address != address(0),
                "Should not transfer to the zero address"
            );
            require(totalAmount > 0, "Should be greater than 0");

            addFrozenWallet(
                _address,
                totalAmount,
                monthlyAmount,
                initialAmount,
                afterDay,
                monthDelay
            );
        }

        return true;
    }

    function addFrozenWallet(
        address wallet,
        uint256 totalAmount,
        uint256 monthlyAmount,
        uint256 initialAmount,
        uint256 afterDays,
        uint256 monthDelay
    ) internal {
        if (!frozenWallets[wallet].scheduled) {
            super._transfer(msg.sender, wallet, totalAmount);
        }

        // Create frozen wallets
        FrozenWallet memory frozenWallet = FrozenWallet(
            wallet,
            totalAmount,
            monthlyAmount,
            initialAmount,
            releaseTime.add(afterDays),
            afterDays,
            true,
            monthDelay
        );

        // Add wallet to frozen wallets
        frozenWallets[wallet] = frozenWallet;
    }

    function getTimestamp() external view returns (uint256) {
        return block.timestamp;
    }

    function getMonths(uint256 afterDays, uint256 monthDelay)
        public
        view
        returns (uint256)
    {
        uint256 time = releaseTime.add(afterDays);

        if (block.timestamp < time) {
            return 0;
        }

        uint256 diff = block.timestamp.sub(time);
        uint256 months = diff.div(30 days).add(1).sub(monthDelay);

        return months;
    }

    function isStarted(uint256 startDay) public view returns (bool) {
        if (block.timestamp < releaseTime || block.timestamp < startDay) {
            return false;
        }

        return true;
    }

    function getTransferableAmount(address sender)
        public
        view
        returns (uint256)
    {
        uint256 months = getMonths(
            frozenWallets[sender].afterDays,
            frozenWallets[sender].monthDelay
        );
        uint256 monthlyTransferableAmount = frozenWallets[sender]
            .monthlyAmount
            .mul(months);
        uint256 transferableAmount = monthlyTransferableAmount.add(
            frozenWallets[sender].initialAmount
        );

        if (transferableAmount > frozenWallets[sender].totalAmount) {
            return frozenWallets[sender].totalAmount;
        }

        return transferableAmount;
    }

    function transferMany(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(
            recipients.length == amounts.length,
            "PAID Token: Wrong array length"
        );
        for (uint256 i = 0; i < recipients.length; i++) {
            address recipient = recipients[i];
            uint256 amount = amounts[i];

            SafeERC20Upgradeable.safeTransfer(this, recipient, amount);
        }
    }

    function getRestAmount(address sender) public view returns (uint256) {
        uint256 transferableAmount = getTransferableAmount(sender);
        uint256 restAmount = frozenWallets[sender].totalAmount.sub(
            transferableAmount
        );

        return restAmount;
    }

    // Transfer control
    function canTransfer(address sender, uint256 amount)
        public
        view
        returns (bool)
    {
        // Control is scheduled wallet
        if (!frozenWallets[sender].scheduled) {
            return true;
        }

        uint256 balance = balanceOf(sender);
        uint256 restAmount = getRestAmount(sender);

        if (
            balance > frozenWallets[sender].totalAmount &&
            balance.sub(frozenWallets[sender].totalAmount) >= amount
        ) {
            return true;
        }

        if (
            !isStarted(frozenWallets[sender].startDay) ||
            balance.sub(amount) < restAmount
        ) {
            return false;
        }

        return true;
    }

    // @override
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(canTransfer(sender, amount), "Wait for vesting day!");
        super._beforeTokenTransfer(sender, recipient, amount);
        require(!isPausedUntilBlock(), "Contract is paused right now");
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = _msgSender().call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
    }

    function isPausedUntilBlock() public view returns (bool) {
        if (_msgSender() == owner()) {
            // owner always can transfer
            return false;
        }
        return (block.number < pausedBeforeBlockNumber);
    }

    /**
     * @dev Pauses the contract for up to one week.
     * (40320 blocks = around 1 week, if every 15s block gets added.)
     */
    function pause() public onlyOwner {
        pausedBeforeBlockNumber = block.number.add(40320);
        emit PausedUntilBlock(pausedBeforeBlockNumber);
    }

    /**
     * @dev Disengages the pause activated by the `pause()` function.
     * the contract will start working again.
     */
    function unpause() public onlyOwner {
        pausedBeforeBlockNumber = 0;
        emit PausedUntilBlock(pausedBeforeBlockNumber);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    function faucetMint(address account, uint256 amount) external onlyOwner {
        super._mint(account, amount);
    }
}