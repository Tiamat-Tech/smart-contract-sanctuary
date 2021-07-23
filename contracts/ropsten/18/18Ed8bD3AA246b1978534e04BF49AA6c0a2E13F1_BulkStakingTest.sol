// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './Readable.sol';


contract BulkStakingTest is Ownable, Readable {
    using SafeMath for *;
    using ExtraMath for *;
    using SafeERC20 for IERC20;

    IERC20 immutable public BULK;

    struct Lock {
        uint128 strategicSale;
        uint128 privateSale;
        uint256 claimed;
        uint88 secondary;
        uint88 requested;
        uint32 readyAt;
    }

    struct DB {
        mapping(address => Lock) locked;
        uint totalBalance;
    }

    DB internal db;

    uint public constant RELEASE_DATE = 1626958730;
    // 20% unlocked on release date. 375 days total.
    uint public constant STRATEGIC = RELEASE_DATE - 75 days;
    uint public constant STRATEGIC_PERIOD = 375 days;
    // 25% unlocked on release date. 400 days total.
    uint public constant PRIVATE = RELEASE_DATE - 100 days;
    uint public constant PRIVATE_PERIOD = 400 days;
    // Full release date 1654084800 is June 1st 2022, 12:00:00.

    uint public constant WITHDRAW_TIMEOUT = 1 hours;

    constructor(IERC20 bulk, address newOwner) {
        BULK = bulk;
        transferOwnership(newOwner);
    }

    function getUserInfo(address who) external view returns(Lock memory) {
        return db.locked[who];
    }

    function getTotalBalance() external view returns(uint) {
        return db.totalBalance;
    }

    function calcualteReleased(uint amount, uint releaseStart, uint releasePeriod)
    private view returns(uint) {
        uint released = amount.mul(since(releaseStart)) / releasePeriod;
        return Math.min(amount, released);
    }

    function availableToClaim(address who) public view returns(uint) {
        if (not(reached(RELEASE_DATE))) {
            return 0;
        }
        Lock memory user = db.locked[who];
        uint releasedStrategic = calcualteReleased(user.strategicSale, STRATEGIC, STRATEGIC_PERIOD);
        uint releasedPrivate = calcualteReleased(user.privateSale, PRIVATE, PRIVATE_PERIOD);
        uint released = releasedStrategic.add(releasedPrivate);
        if (user.claimed >= released) {
            return 0;
        }
        return released.sub(user.claimed);
    }

    function availableToWithdraw(address who) public view returns(uint) {
        Lock storage user = db.locked[who];
        uint readyAt = user.readyAt;
        uint requested = user.requested;
        if (readyAt > 0 && passed(readyAt)) {
            return requested;
        }
        return 0;
    }

    function balanceOf(address who) external view returns(uint) {
        Lock memory user = db.locked[who];
        return user.strategicSale.add(user.privateSale).add(user.secondary)
            .sub(user.claimed).sub(availableToWithdraw(who));
    }

    function assignStrategic(address[] calldata tos, uint[] calldata amounts)
    external onlyOwner {
        uint len = tos.length;
        require(len == amounts.length, 'Invalid input');
        uint total = 0;
        for (uint i = 0; i < len; i++) {
            address to = tos[i];
            uint amount = amounts[i];
            db.locked[to].strategicSale = db.locked[to].strategicSale.add(amount).toUInt128();
            total = total.add(amount);
            emit StrategicAssigned(to, amount);
        }
        db.totalBalance = db.totalBalance.add(total);
        BULK.safeTransferFrom(msg.sender, address(this), total);
    }

    function assignPrivate(address[] calldata tos, uint[] calldata amounts)
    external onlyOwner {
        uint len = tos.length;
        require(len == amounts.length, 'Invalid input');
        uint total = 0;
        for (uint i = 0; i < len; i++) {
            address to = tos[i];
            uint amount = amounts[i];
            db.locked[to].privateSale = db.locked[to].privateSale.add(amount).toUInt128();
            total = total.add(amount);
            emit PrivateAssigned(to, amount);
        }
        db.totalBalance = db.totalBalance.add(total);
        BULK.safeTransferFrom(msg.sender, address(this), total);
    }

    function claim() public {
        uint claimable = availableToClaim(msg.sender);
        require(claimable > 0, 'Nothing to claim');
        Lock storage user = db.locked[msg.sender];
        user.claimed = user.claimed.add(claimable);
        db.totalBalance = db.totalBalance.sub(claimable);
        BULK.safeTransfer(msg.sender, claimable);
        emit Claimed(msg.sender, claimable);
    }

    function stake(uint amount) external {
        Lock storage user = db.locked[msg.sender];
        user.secondary = user.secondary.add(amount).toUInt88();
        user.readyAt = 0;
        user.requested = 0;
        db.totalBalance = db.totalBalance.add(amount);
        BULK.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function restake() external {
        Lock storage user = db.locked[msg.sender];
        uint requested = user.requested;
        user.readyAt = 0;
        user.requested = 0;
        emit Restaked(msg.sender, requested);
    }

    function requestWithdrawal(uint amount) external {
        Lock storage user = db.locked[msg.sender];
        uint readyAt = block.timestamp + WITHDRAW_TIMEOUT;
        require(user.secondary >= amount, 'Insufficient balance to withdraw');
        user.readyAt = readyAt.toUInt32();
        user.requested = amount.toUInt88();
        emit WithdrawRequested(msg.sender, amount, readyAt);
    }

    function withdraw() public {
        uint withdrawable = availableToWithdraw(msg.sender);
        require(withdrawable > 0, 'Nothing to withdraw');
        Lock storage user = db.locked[msg.sender];
        user.secondary = user.secondary.sub(withdrawable).toUInt88();
        user.readyAt = 0;
        user.requested = 0;
        db.totalBalance = db.totalBalance.sub(withdrawable);
        BULK.safeTransfer(msg.sender, withdrawable);
        emit Withdrawn(msg.sender, withdrawable);
    }

    function withdrawEarly(address who, uint amount) external onlyOwner {
        Lock storage user = db.locked[who];
        user.secondary = user.secondary.sub(amount).toUInt88();
        user.readyAt = 0;
        user.requested = 0;
        db.totalBalance = db.totalBalance.sub(amount);
        BULK.safeTransfer(msg.sender, amount);
        emit WithdrawnEarly(who, amount);
    }

    function claimEarly(address who, uint amount) external onlyOwner {
        Lock storage user = db.locked[who];
        Lock memory userData = user;
        uint unclaimed = userData.strategicSale.add(userData.privateSale).sub(userData.claimed);
        require(amount <= unclaimed, 'Insufficient unclaimed');
        user.claimed = user.claimed.add(amount);
        db.totalBalance = db.totalBalance.sub(amount);
        BULK.safeTransfer(msg.sender, amount);
        emit ClaimedEarly(who, amount);
    }

    function claimAndWithdraw() external {
        claim();
        if (availableToWithdraw(msg.sender) == 0) {
            return;
        }
        withdraw();
    }

    function recover(IERC20 token, address to, uint amount) external onlyOwner {
        if (token == BULK) {
            require(BULK.balanceOf(address(this)).sub(db.totalBalance) >= amount,
                'Not enough to recover');
        }
        token.safeTransfer(to, amount);
        emit Recovered(token, to, amount);
    }

    event StrategicAssigned(address user, uint amount);
    event PrivateAssigned(address user, uint amount);
    event Claimed(address user, uint amount);
    event Staked(address user, uint amount);
    event Restaked(address user, uint amount);
    event WithdrawRequested(address user, uint amount, uint readyAt);
    event Withdrawn(address user, uint amount);
    event WithdrawnEarly(address user, uint amount);
    event ClaimedEarly(address user, uint amount);
    event Recovered(IERC20 token, address to, uint amount);
}