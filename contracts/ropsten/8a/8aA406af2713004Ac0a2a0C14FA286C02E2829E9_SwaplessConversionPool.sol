// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {IConversionPool} from "@orionterra/eth-anchor-contracts/contracts/extensions/ConversionPool.sol";
import {IExchangeRateFeeder} from "@orionterra/eth-anchor-contracts/contracts/extensions/ExchangeRateFeeder.sol";
import {Operator} from "@orionterra/eth-anchor-contracts/contracts/utils/Operator.sol";

import {IERC20Controlled, ERC20Controlled} from "@orionterra/eth-anchor-contracts/contracts/utils/ERC20Controlled.sol";
import {IRouter} from "@orionterra/eth-anchor-contracts/contracts/core/Router.sol";

contract SwaplessConversionPool is IConversionPool, Context, Operator, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Controlled;

     // pool token settings
    IERC20 public inputToken;
    IERC20Controlled public outputToken;

    // proxy settings
    IERC20 public proxyInputToken; // UST
    IERC20 public proxyOutputToken; // aUST
    uint256 public proxyReserve = 0; // aUST reserve

    address public optRouter;
    IExchangeRateFeeder public feeder;

    // flags
    bool public isDepositAllowed = true;
    bool public isRedemptionAllowed = true;

    function initialize(
        // ===== tokens
        string memory _outputTokenName,
        string memory _outputTokenSymbol,
        address _inputToken,
        address _proxyOutputToken,
        // ===== others
        address _optRouter,
        address _exchangeRateFeeder
    ) public initializer {
        inputToken = IERC20(_inputToken);
        outputToken = new ERC20Controlled(_outputTokenName, _outputTokenSymbol);

        proxyInputToken = IERC20(_inputToken);          //
        proxyOutputToken = IERC20(_proxyOutputToken);

        setOperationRouter(_optRouter);
        setExchangeRateFeeder(_exchangeRateFeeder);
    }

    function setOperationRouter(address _optRouter) public onlyOwner {
        optRouter = _optRouter;
        proxyInputToken.safeApprove(optRouter, type(uint256).max);
        proxyOutputToken.safeApprove(optRouter, type(uint256).max);
    }

    function setExchangeRateFeeder(address _exchangeRateFeeder)
        public
        onlyOwner
    {
        feeder = IExchangeRateFeeder(_exchangeRateFeeder);
    }

    function setDepositAllowance(bool _allow) public onlyOwner {
        isDepositAllowed = _allow;
    }

    function setRedemptionAllowance(bool _allow) public onlyOwner {
        isRedemptionAllowed = _allow;
    }

    // migrate
    function migrate(address _to) public onlyOwner {
        require(
            !(isDepositAllowed && isRedemptionAllowed),
            "ConversionPool: invalid status"
        );

        proxyOutputToken.transfer(
            _to,
            proxyOutputToken.balanceOf(address(this))
        );
    }

    // reserve

    function provideReserve(uint256 _amount) public onlyGranted {
        proxyReserve = proxyReserve.add(_amount);
        proxyOutputToken.safeTransferFrom(
            super._msgSender(),
            address(this),
            _amount
        );
    }

    function removeReserve(uint256 _amount) public onlyGranted {
        proxyReserve = proxyReserve.sub(_amount);
        proxyOutputToken.safeTransfer(super._msgSender(), _amount);
    }

    // operations

    modifier _updateExchangeRate {
        feeder.update(address(inputToken));

        _;
    }

    function deposit(uint256 _amount) public override {
        require(isDepositAllowed, "ConversionPool: deposit not stopped");

        inputToken.safeTransferFrom(super._msgSender(), address(this), _amount);

        IRouter(optRouter).depositStable(_amount);

        uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
        outputToken.mint(super._msgSender(), _amount.mul(1e18).div(pER));
    }

    function deposit(uint256 _amount, uint256 _minAmountOut) public override {
        deposit(_amount);
    }

    function redeem(uint256 _amount) public override {
        require(isRedemptionAllowed, "ConversionPool: redemption not allowed");

        outputToken.burnFrom(super._msgSender(), _amount);

        IRouter(optRouter).redeemStable(super._msgSender(), _amount);
    }

    function redeem(uint256 _amount, uint256 _minAmountOut) public override {
        redeem(_amount);
    }
}