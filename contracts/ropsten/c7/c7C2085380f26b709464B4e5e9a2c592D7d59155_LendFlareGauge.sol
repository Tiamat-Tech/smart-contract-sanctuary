// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libs/SafeERC20.sol";
import "./common/IVirtualBalanceWrapper.sol";


interface ILendFlareToken {
    function future_epoch_time_write() external returns (uint256);

    function rate() external view returns (uint256);
}

interface IMinter {
    function minted(address addr, address self) external view returns (uint256);
}

interface IController {
    function gauge_relative_weight(
        address addr /* , uint256 time */
    ) external view returns (uint256);
}

contract LendFlareGauge {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant TOKENLESS_PRODUCTION = 40;
    uint256 constant BOOST_WARMUP = 2 * 7 * 86400;
    uint256 constant WEEK = 604800;

    address public virtualBalance;
    uint256 public working_supply;
    uint256 public period;
    uint256 public inflation_rate;
    uint256 public future_epoch_time;

    address public lendFlareVotingEscrow;
    address public lendFlareToken;
    address public lendFlareTokenMinter;
    address public lendFlareGaugeModel;

    uint256[100000000000000000000000000000] public period_timestamp;
    uint256[100000000000000000000000000000] public integrate_inv_supply;

    mapping(address => uint256) public integrate_inv_supply_of;
    mapping(address => uint256) public integrate_checkpoint_of;
    mapping(address => uint256) public integrate_fraction;
    mapping(address => uint256) public working_balances;

    event UpdateLiquidityLimit(
        address user,
        uint256 original_balance,
        uint256 original_supply,
        uint256 working_balance,
        uint256 working_supply
    );

    constructor(
        address _virtualBalance,
        address _lendFlareToken,
        address _lendFlareVotingEscrow,
        address _lendFlareGaugeModel,
        address _lendFlareTokenMinter
    ) public {
        virtualBalance = _virtualBalance;
        lendFlareVotingEscrow = _lendFlareVotingEscrow;
        lendFlareToken = _lendFlareToken;
        lendFlareTokenMinter = _lendFlareTokenMinter;
        lendFlareGaugeModel = _lendFlareGaugeModel;
    }

    function _update_liquidity_limit(
        address addr,
        uint256 l,
        uint256 L
    ) internal {
        uint256 voting_balance = IERC20(lendFlareVotingEscrow).balanceOf(addr);
        uint256 voting_total = IERC20(lendFlareVotingEscrow).totalSupply();
        uint256 lim = (l * TOKENLESS_PRODUCTION) / 100;

        if (
            voting_total > 0 &&
            block.timestamp > period_timestamp[0] + BOOST_WARMUP
        ) {
            lim +=
                (((L * voting_balance) / voting_total) *
                    (100 - TOKENLESS_PRODUCTION)) /
                100;
        }

        lim = min(l, lim);

        uint256 old_bal = working_balances[addr];

        working_balances[addr] = lim;

        uint256 _working_supply = working_supply + lim - old_bal;
        working_supply = _working_supply;

        emit UpdateLiquidityLimit(addr, l, L, lim, _working_supply);
    }

    function _checkpoint(address addr) internal {
        uint256 _period_time = period_timestamp[period];
        uint256 _integrate_inv_supply = integrate_inv_supply[period];
        uint256 rate = inflation_rate;
        uint256 new_rate = rate;
        uint256 prev_future_epoch = future_epoch_time;

        if (prev_future_epoch >= _period_time) {
            future_epoch_time = ILendFlareToken(lendFlareToken)
                .future_epoch_time_write();
            new_rate = ILendFlareToken(lendFlareToken).rate();
            inflation_rate = new_rate;
        }

        // Controller(_controller).checkpoint_gauge(address(this));

        uint256 _working_balance = working_balances[addr];
        uint256 _working_supply = working_supply;

        if (block.timestamp > _period_time) {
            uint256 prev_week_time = _period_time;
            uint256 week_time = min(
                ((_period_time + WEEK) / WEEK) * WEEK,
                block.timestamp
            );

            for (uint256 i = 0; i < 500; i++) {
                uint256 dt = week_time - prev_week_time;
                // uint256 w = IController(lendFlareGaugeModel).gauge_relative_weight(
                //     address(this),
                //     (prev_week_time / WEEK) * WEEK
                // );
                uint256 w = IController(lendFlareGaugeModel)
                    .gauge_relative_weight(address(this));

                if (_working_supply > 0) {
                    if (
                        prev_future_epoch >= prev_week_time &&
                        prev_future_epoch < week_time
                    ) {
                        _integrate_inv_supply +=
                            (rate * w * (prev_future_epoch - prev_week_time)) /
                            _working_supply;
                        rate = new_rate;
                        _integrate_inv_supply +=
                            (rate * w * (week_time - prev_future_epoch)) /
                            _working_supply;
                    } else {
                        _integrate_inv_supply +=
                            (rate * w * dt) /
                            _working_supply;
                    }

                    if (week_time == block.timestamp) break;

                    prev_week_time = week_time;
                    week_time = min(week_time + WEEK, block.timestamp);
                }
            }
        }

        period += 1;
        period_timestamp[period] = block.timestamp;
        integrate_inv_supply[period] = _integrate_inv_supply;

        integrate_fraction[addr] +=
            (_working_balance *
                (_integrate_inv_supply - integrate_inv_supply_of[addr])) /
            10**18;
        integrate_inv_supply_of[addr] = _integrate_inv_supply;
        integrate_checkpoint_of[addr] = block.timestamp;

        // _token: address = self.crv_token
        // _controller: address = self.controller
        // _period: int128 = self.period
        // _period_time: uint256 = self.period_timestamp[_period]
        // _integrate_inv_supply: uint256 = self.integrate_inv_supply[_period]
        // rate: uint256 = self.inflation_rate
        // new_rate: uint256 = rate
        // prev_future_epoch: uint256 = self.future_epoch_time
        // if prev_future_epoch >= _period_time:
        //     self.future_epoch_time = CRV20(_token).future_epoch_time_write()
        //     new_rate = CRV20(_token).rate()
        //     self.inflation_rate = new_rate
        // Controller(_controller).checkpoint_gauge(self)

        // _working_balance: uint256 = self.working_balances[addr]
        // _working_supply: uint256 = self.working_supply

        /* # Update integral of 1/supply
        if block.timestamp > _period_time:
            prev_week_time: uint256 = _period_time
            week_time: uint256 = min((_period_time + WEEK) / WEEK * WEEK, block.timestamp)

            for i in range(500):
                dt: uint256 = week_time - prev_week_time
                w: uint256 = Controller(_controller).gauge_relative_weight(self, prev_week_time / WEEK * WEEK)

                if _working_supply > 0:
                    if prev_future_epoch >= prev_week_time and prev_future_epoch < week_time:
                        # If we went across one or multiple epochs, apply the rate
                        # of the first epoch until it ends, and then the rate of
                        # the last epoch.
                        # If more than one epoch is crossed - the gauge gets less,
                        # but that'd meen it wasn't called for more than 1 year
                        _integrate_inv_supply += rate * w * (prev_future_epoch - prev_week_time) / _working_supply
                        rate = new_rate
                        _integrate_inv_supply += rate * w * (week_time - prev_future_epoch) / _working_supply
                    else:
                        _integrate_inv_supply += rate * w * dt / _working_supply
                    # On precisions of the calculation
                    # rate ~= 10e18
                    # last_weight > 0.01 * 1e18 = 1e16 (if pool weight is 1%)
                    # _working_supply ~= TVL * 1e18 ~= 1e26 ($100M for example)
                    # The largest loss is at dt = 1
                    # Loss is 1e-9 - acceptable

                if week_time == block.timestamp:
                    break
                prev_week_time = week_time
                week_time = min(week_time + WEEK, block.timestamp)

        _period += 1
        self.period = _period
        self.period_timestamp[_period] = block.timestamp
        self.integrate_inv_supply[_period] = _integrate_inv_supply

        # Update user-specific integrals
        self.integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - self.integrate_inv_supply_of[addr]) / 10 ** 18
        self.integrate_inv_supply_of[addr] = _integrate_inv_supply
        self.integrate_checkpoint_of[addr] = block.timestamp */
    }

    function user_checkpoint(address addr) public returns (bool) {
        _checkpoint(addr);
        // _update_liquidity_limit(addr,balanceOf[addr],totalSupply);
        _update_liquidity_limit(
            addr,
            IVirtualBalanceWrapper(virtualBalance).balanceOf(addr),
            IVirtualBalanceWrapper(virtualBalance).totalSupply()
        );

        return true;
    }

    function claimable_tokens(address addr) public returns (uint256) {
        _checkpoint(addr);
        // _update_liquidity_limit(addr,balanceOf[addr],totalSupply);
        // _update_liquidity_limit(
        //     addr,
        //     IVirtualBalanceWrapper(virtualBalance).balanceOf(addr),
        //     IVirtualBalanceWrapper(virtualBalance).totalSupply()
        // );

        return
            integrate_fraction[addr] -
            IMinter(lendFlareTokenMinter).minted(addr, address(this));
    }

    function integrate_checkpoint() public view returns (uint256) {
        return period_timestamp[period];
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}