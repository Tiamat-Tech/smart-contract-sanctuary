// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is Ownable {
    event Vest(
        address indexed to,
        uint amount,
        uint start,
        uint cliff,
        uint vesting
    );
    event Claim(address indexed claimer, uint index, uint amount);

    struct Schedule {
        // total amount locked
        uint amount;
        // total claimed
        uint claimed;
        // timestamp when this schedule was created
        uint start;
        // timestamp when cliff ends
        uint cliff;
        // timestamp when vesting ends
        uint end;
    }

    // Interval before claimable amount increases
    uint private constant INTERVAL = 30 days;

    IERC20 public immutable breederToken;

    // user => Schedule[]
    mapping(address => Schedule[]) public schedules;
    // total amount locked in this contract
    uint public totalLocked;

    constructor(address _breeder) {
        require(_breeder != address(0), "invalid breeder address");
        breederToken = IERC20(_breeder);
    }

    function _vest(
        address account,
        uint amount,
        uint start,
        uint cliff,
        uint vesting
    ) private {
        require(account != address(0), "account = zero address");
        require(amount > 0, "amount = 0");
        // TODO: max cap on start?
        require(start >= block.timestamp, "start < timestamp");
        // TODO: max cap on vesting and cliff?
        require(vesting > 0 && vesting >= cliff, "invalid vesting");

        totalLocked += amount;
        require(
            breederToken.balanceOf(address(this)) >= totalLocked,
            "balance < locked + amount"
        );

        schedules[account].push(
            Schedule({
                amount: amount,
                claimed: 0,
                start: start,
                cliff: start + cliff,
                end: start + vesting
            })
        );

        emit Vest(account, amount, start, cliff, vesting);
    }

    /**
     * @notice Sets up a vesting schedule for a set user.
     * @param account account that a vesting schedule is being set up for.
     *        Will be able to claim tokens after the cliff period.
     * @param amount amount of tokens being vested for the user.
     * @param start timestamp for when this vesting should have started
     * @param cliff seconds that the cliff will be present for.
     * @param vesting seconds the tokens will vest over (linearly)
     */
    function vest(
        address account,
        uint amount,
        uint start,
        uint cliff,
        uint vesting
    ) external onlyOwner {
        // TODO: pull or push?
        // breederToken.transferFrom(msg.sender, address(this), amount);
        _vest(account, amount, start, cliff, vesting);
    }

    /**
     * @notice Returns schedule count
     * @param account account
     */
    function getScheduleCount(address account) external view returns (uint) {
        return schedules[account].length;
    }

    /**
     * @notice Sets up vesting schedules for multiple users within 1 transaction.
     * @param accounts an array of the accounts that the vesting schedules are being set up for.
     *                 Will be able to claim tokens after the cliff period.
     * @param amounts an array of the amount of tokens being vested for each user.
     * @param start the timestamp for when this vesting should have started
     * @param cliff the number of seconds that the cliff will be present at.
     * @param vesting the number of seconds the tokens will vest over (linearly)
     */
    function multiVest(
        address[] calldata accounts,
        uint[] calldata amounts,
        uint start,
        uint cliff,
        uint vesting
    ) external onlyOwner {
        require(accounts.length == amounts.length, "array length");

        // TODO: pull or push?
        // uint total;
        // for (uint i; i < amounts.length; i++) {
        //     total += amount[i];
        // }
        // breederToken.transferFrom(msg.sender, address(this), total);

        for (uint i; i < accounts.length; i++) {
            _vest(accounts[i], amounts[i], start, cliff, vesting);
        }
    }

    /**
     * @return Calculates the amount of tokens to distribute to an account at
     *         any instance in time.
     * @param amount amount vested
     * @param claimed amount claimed
     * @param start timestamp
     * @param cliff timstamp
     * @param end timestamp
     * @param timestamp current timestamp
     */
    function getClaimableAmount(
        uint amount,
        uint claimed,
        uint start,
        uint cliff,
        uint end,
        uint timestamp
    ) public pure returns (uint) {
        // return 0 if not vested
        if (amount == 0) {
            return 0;
        }

        // time < cliff
        if (timestamp < cliff) {
            return 0;
        }

        // time >= end
        if (timestamp >= end) {
            return amount - claimed;
        }

        // cliff <= time < end
        /*
        y = amount claimable, assuming claimed amount = 0
        t = block.timestamp

        y0 = claimable at cliff
           = amount * (cliff - start) / (end - start)

        s = step function for each month after cliff
           = floor((t - cliff) / interval)

        dy for each month
           = amount * interval / (end - start)

        y1 = claimable each month after cliff
           = dy * s

        y = y0 + y1
          = amount * ((cliff - start) + interval * floor((t - cliff) / interval)) / (end - start)
        */
        uint y = (amount *
            ((cliff - start) + INTERVAL * ((timestamp - cliff) / INTERVAL))) /
            (end - start);
        return y - claimed;
    }

    /**
     * @notice allows users to claim vested tokens if the cliff time has passed.
     * @param index which schedule the user is claiming against
     */
    function claim(uint index) external {
        Schedule storage schedule = schedules[msg.sender][index];

        uint amount = getClaimableAmount(
            schedule.amount,
            schedule.claimed,
            schedule.start,
            schedule.cliff,
            schedule.end,
            block.timestamp
        );
        require(amount > 0, "claimable amount = 0");

        // TODO: invariant test claimed <= schedule.amount
        schedule.claimed += amount;

        // TODO: invariant test totalLocked <= bal
        totalLocked -= amount;
        breederToken.transfer(msg.sender, amount);

        emit Claim(msg.sender, index, amount);
    }

    // TODO: cancel / rug?

    /**
     * @notice Withdraws excess BREED tokens from the contract.
     */
    function withdraw(uint amount) external onlyOwner {
        require(
            breederToken.balanceOf(address(this)) - totalLocked >= amount,
            "amount > excess"
        );
        breederToken.transfer(owner(), amount);
    }
}