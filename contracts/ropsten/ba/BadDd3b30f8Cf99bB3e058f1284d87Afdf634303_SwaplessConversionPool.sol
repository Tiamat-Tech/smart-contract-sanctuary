// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IConversionPool} from "@orionterra/eth-anchor-contracts/contracts/extensions/ConversionPool.sol";
import {ExchangeRateFeeder} from "@orionterra/eth-anchor-contracts/contracts/extensions/ExchangeRateFeeder.sol";

import {IERC20Controlled, ERC20Controlled} from "@orionterra/eth-anchor-contracts/contracts/utils/ERC20Controlled.sol";
import {IRouter} from "@orionterra/eth-anchor-contracts/contracts/core/Router.sol";

contract SwaplessConversionPool is IConversionPool, OwnableUpgradeable {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Controlled;

     // pool token settings
    IERC20 public inputToken;
    uint256 public inputToken10PowDecimals;  // 10^decimals for inputToken, i.e. amount equals to $1
    IERC20Controlled public outputToken;  // vaUST

    // proxy settings
    IERC20 public proxyInputToken;   // UST
    IERC20 public proxyOutputToken;  // aUST
    uint256 public proxyReserve;     // aUST reserve

    address public optRouter;

    // implementation of ExchangeRateFeeder required to access feeder.tokens[inputToken].weight
    ExchangeRateFeeder public feeder;

    // flags
    bool public isDepositAllowed;
    bool public isRedemptionAllowed;

    function initialize(
      // ===== tokens
      string memory _outputTokenName,
      string memory _outputTokenSymbol,
      address _inputToken,
      address _proxyOutputToken,
      // ===== others
      address _optRouter,
      address _exchangeRateFeeder,
      uint32 _input_token_decimals
    ) public virtual initializer {
      require(_input_token_decimals <= 70);

      OwnableUpgradeable.__Ownable_init();

      inputToken = IERC20(_inputToken);
      outputToken = new ERC20Controlled(_outputTokenName, _outputTokenSymbol);

      proxyInputToken = IERC20(_inputToken);          //
      proxyOutputToken = IERC20(_proxyOutputToken);
      proxyReserve = 0;

      setOperationRouter(_optRouter);
      setExchangeRateFeeder(_exchangeRateFeeder);
      inputToken10PowDecimals = 10 ** _input_token_decimals;

      isDepositAllowed = true;
      isRedemptionAllowed = true;
    }

    function setOperationRouter(address _optRouter) public onlyOwner {
      optRouter = _optRouter;
      proxyInputToken.safeApprove(optRouter, type(uint256).max);
      proxyOutputToken.safeApprove(optRouter, type(uint256).max);
    }

    function setExchangeRateFeeder(address _exchangeRateFeeder) public onlyOwner {
      feeder = ExchangeRateFeeder(_exchangeRateFeeder);
    }

    function setDepositAllowance(bool _allow) public onlyOwner {
      isDepositAllowed = _allow;
    }

    function setRedemptionAllowance(bool _allow) public onlyOwner {
      isRedemptionAllowed = _allow;
    }

    // reserve

    function provideReserve(uint256 _amount) public {
      proxyReserve = proxyReserve.add(_amount);
      proxyOutputToken.safeTransferFrom(
          super._msgSender(),
          address(this),
          _amount
      );
    }

    function removeReserve(uint256 _amount) public onlyOwner {
      proxyReserve = proxyReserve.sub(_amount);
      proxyOutputToken.safeTransfer(super._msgSender(), _amount);
    }

    // operations

    modifier _updateExchangeRate {
      feeder.update(address(inputToken));

      _;
    }

    function get_shuttle_fee(uint256 amount) internal view returns(uint256) {
      // max($1, 0.1% * amount)
      return amount.div(1000).max(inputToken10PowDecimals);
    }

    function get_feeder_rate() internal view returns(uint256) {
      (/* ExchangeRateFeeder.Status status */,
       /* uint256 exchangeRate */,
       /* uint256 period */,
       uint256 weight,
       /* uint256 lastUpdatedAt */) = feeder.tokens(address(inputToken));
      require(weight > 1e18);  // rate > 1.0
      return weight;
    }

    function deposit(uint256 _amount) public override _updateExchangeRate {
      require(isDepositAllowed, "ConversionPool: deposit not stopped");

      inputToken.safeTransferFrom(super._msgSender(), address(this), _amount);

      IRouter(optRouter).depositStable(_amount);

      uint256 pER = feeder.exchangeRateOf(address(inputToken), false);
      uint256 pER_last_epoch = pER.mul(get_feeder_rate()).div(1e18);

      uint256 amount_with_fee = _amount.sub(get_shuttle_fee(_amount));
      outputToken.mint(super._msgSender(), amount_with_fee.mul(1e18).div(pER_last_epoch));
    }

    function deposit(uint256 _amount, uint256 _minAmountOut) public override {
      deposit(_amount);
    }

    function redeem(uint256 _amount) public override _updateExchangeRate {
      require(isRedemptionAllowed, "ConversionPool: redemption not allowed");

      outputToken.burnFrom(super._msgSender(), _amount);

      IRouter(optRouter).redeemStable(super._msgSender(), _amount);
    }

    function redeem(uint256 _amount, uint256 _minAmountOut) public override {
      redeem(_amount);
    }

    function profitAmount() public view returns (uint256) {
      uint256 aUST_Owned = proxyOutputToken.balanceOf(address(this));
      if (proxyReserve >= aUST_Owned) return 0;
      // total vaUST - aUST(this pool) - proxyReserve = earnable amount
      uint256 total_vaUST = outputToken.totalSupply();
      uint256 aUST_Available = aUST_Owned.sub(proxyReserve);

      if (aUST_Available < total_vaUST) return 0;

      return aUST_Available - total_vaUST;
    }

    function takeProfit(address receiver) public onlyOwner {
      uint256 aUST_Owned = proxyOutputToken.balanceOf(address(this));
      require(proxyReserve < aUST_Owned, "ConversionPool: not enough balance");
      // total vaUST - aUST(this pool) - proxyReserve = earnable amount
      uint256 total_vaUST = outputToken.totalSupply();
      uint256 aUST_Available = aUST_Owned.sub(proxyReserve);
      require(aUST_Available > total_vaUST, "ConversionPool: no aUST available to take profit");

      uint256 earnAmount = aUST_Available.sub(total_vaUST);
      proxyOutputToken.safeTransfer(receiver, earnAmount);
    }
}