// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import { IConversionPool } from "@orionterra/eth-anchor-contracts/contracts/extensions/ConversionPool.sol";
import { IExchangeRateFeeder } from "@orionterra/eth-anchor-contracts/contracts/extensions/ExchangeRateFeeder.sol";
import { Operator } from "@orionterra/eth-anchor-contracts/contracts/utils/Operator.sol";

import {IERC20Controlled, ERC20Controlled} from "@orionterra/eth-anchor-contracts/contracts/utils/ERC20Controlled.sol";
import {IRouter} from "@orionterra/eth-anchor-contracts/contracts/core/Router.sol";

contract USTPool  is IConversionPool, Context, Operator, Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20Controlled;

     // pool token settings
    IERC20 public inputToken;
    IERC20Controlled public outputToken;

    IERC20 public proxyToken; // aUST

    IRouter public optRouter;

    function initialize(
        // ===== tokens
        string memory _outputTokenName,
        string memory _outputTokenSymbol,
        address _inputToken,
        address _proxyToken,
        address _optRouter
    ) public initializer {
        inputToken = IERC20(_inputToken);
        outputToken = new ERC20Controlled(_outputTokenName, _outputTokenSymbol);

        proxyToken = IERC20(_proxyToken);

        setOperationRouter(_optRouter);
    }

    function setOperationRouter(address _optRouter) public onlyOwner {
        optRouter = IRouter(_optRouter);
        inputToken.safeApprove(address(optRouter), type(uint256).max);
        proxyToken.safeApprove(address(optRouter), type(uint256).max);
    }

    function deposit(uint256 _amount) public override {
        inputToken.safeTransferFrom(msg.sender, address(this), _amount);

        optRouter.depositStable(_amount);
        
        outputToken.mint(msg.sender, _amount);
    }

    function redeem(uint256 _amount) public override {
        outputToken.burnFrom(msg.sender, _amount);

        optRouter.redeemStable(msg.sender, _amount);
    }
}