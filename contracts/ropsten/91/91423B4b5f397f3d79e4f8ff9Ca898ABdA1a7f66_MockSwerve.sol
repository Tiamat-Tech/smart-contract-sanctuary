// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ISwerve} from "../interfaces/swerve/ISwerve.sol";
import {ISwerveGauge} from "../interfaces/swerve/ISwerveGauge.sol";
import {ISwerveMinter} from "../interfaces/swerve/ISwerveMinter.sol";
import {ISwervePool} from "../interfaces/swerve/ISwervePool.sol";
import {MockDAI, MockUSDC, MockUSDT, MockTUSD} from "./MockStablecoins.sol";

contract MockSwerveUSD is ERC20 {
    constructor() ERC20("Swerve.fi DAI/USDC/USDT/TUSD", "swUSD") {
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}

contract MockSwerve is ISwerve {
    uint256[4] private PRECISION_MUL = [1, 1000000000000, 1000000000000, 1];
    uint256 private sharePrice = 1e18;

    function calc_token_amount(
        uint256[4] calldata amounts,
        bool
    ) external override view returns (uint256) {
        uint256 tokenAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            tokenAmount += (amounts[i] * PRECISION_MUL[i]);
        }
        return tokenAmount * 1e18 / sharePrice;
    }

    function set_virtual_price(uint256 price) external {
        sharePrice = price;
    }

    function get_virtual_price() external override view returns (uint256) {
        return sharePrice;
    }
}

contract MockSwervePool is Context, ISwervePool {
    using SafeERC20 for IERC20;

    uint256[4] private PRECISION_MUL = [1, 1000000000000, 1000000000000, 1];
    IERC20[4] private tokens = [
        IERC20(new MockDAI()),
        IERC20(new MockUSDC()),
        IERC20(new MockUSDT()),
        IERC20(new MockTUSD())
    ];
    MockSwerveUSD private swUSDToken = new MockSwerveUSD();
    MockSwerve private swerve = new MockSwerve();

    function add_liquidity(uint256[4] memory uamounts, uint256) external override {
        uint256 swusdAmount = 0;
        for (uint256 i = 0; i < 4; i++) {
            if (uamounts[i] > 0) {
                tokens[i].safeTransferFrom(_msgSender(), address(this), uamounts[i]);
                swusdAmount += (uamounts[i] * PRECISION_MUL[i]);
            }
        }
        if (swusdAmount > 0) {
            swUSDToken.mint(_msgSender(), swusdAmount * 1e18 / swerve.get_virtual_price());
        }
    }

    function remove_liquidity_one_coin(
        uint256 _token_amount,
        int128 i,
        uint256
    ) external override {
        IERC20(swUSDToken).safeTransferFrom(_msgSender(), address(this), _token_amount);
        swUSDToken.burn(_token_amount);
        tokens[uint256(int256(i))].safeTransfer(
            _msgSender(),
            (_token_amount * swerve.get_virtual_price()) / (PRECISION_MUL[uint256(int256(i))] * 1e18));
    }

    function calc_withdraw_one_coin(
        uint256 _token_amount,
        int128 i
    ) external override view returns (uint256) {
        return (_token_amount * swerve.get_virtual_price()) / (PRECISION_MUL[uint256(int256(i))] * 1e18);
    }

    function token() external override view returns (address) {
        return address(swUSDToken);
    }

    function curve() external override view returns (ISwerve) {
        return swerve;
    }

    function underlying_coins(int128 id) external override view returns (address) {
        return address(tokens[uint256(int256(id))]);
    }
}


contract MockSWRV is ERC20 {
    constructor() ERC20("Swerve DAO Token", "SWRV") {
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}

contract MockSwerveMinter is Context, ISwerveMinter {
    MockSWRV private swrv = new MockSWRV();

    function mint(address) override external {
        swrv.mint(_msgSender(), 100 * 1e18);
    }

    function token() external override view returns (address) {
        return address(swrv);
    }
}

contract MockSwerveGauge is Context, ISwerveGauge {
    using SafeERC20 for IERC20;

    IERC20 public lp_token;
    mapping (address => uint256) private balances;
    MockSwerveMinter private swerveMinter = new MockSwerveMinter();

    constructor(address _lp_token) {
        lp_token = IERC20(_lp_token);
    }

    function balanceOf(address depositor) external override view returns (uint256) {
        return balances[depositor];
    }

    function minter() external override view returns (ISwerveMinter) {
        return swerveMinter;
    }

    function deposit(uint256 amount) external override {
        lp_token.safeTransferFrom(_msgSender(), address(this), amount);
        balances[_msgSender()] += amount;
    }

    function withdraw(uint256 amount) external override {
        uint256 accountBalance = balances[_msgSender()];
        balances[_msgSender()] = accountBalance - amount;
        lp_token.safeTransfer(_msgSender(), amount);
    }
}