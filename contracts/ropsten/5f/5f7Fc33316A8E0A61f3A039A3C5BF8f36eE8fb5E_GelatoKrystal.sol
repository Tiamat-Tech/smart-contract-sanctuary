// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.6;
pragma experimental ABIEncoderV2;

// import {
//   IERC20Ext,
//   SafeERC20
// } from "../../vendor/openzeppelin/contracts/token/ERC20/SafeERC20.sol";
// import {
//   SafeMath
// } from "../../vendor/openzeppelin/contracts/math/SafeMath.sol";
import {
    SafeERC20,
    SafeMath
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {IERC20Ext} from "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

import {
    ISmartWalletSwapImplementation
} from "../../interfaces/krystal/ISmartWalletSwapImplementation.sol";
import {
    IChainlinkOracle
} from "../../interfaces/chainlink/IChainlinkOracle.sol";
import {IOracleAggregator} from "../../interfaces/gelato/IOracleAggregator.sol";
import {ITaskStorage} from "../../interfaces/gelato/ITaskStorage.sol";
import {
    IUniswapV2Router02
} from "../../interfaces/dapps/Uniswap/IUniswapV2Router02.sol";
import {ServicePostExecFee} from "../standards/ServicePostExecFee.sol";
import "hardhat/console.sol";

contract GelatoKrystal is ServicePostExecFee {
    struct Order {
        address user;
        address inToken;
        address outToken;
        uint256 amountPerTrade;
        uint256 nTradesLeft;
        uint256 minSlippage;
        uint256 maxSlippage;
        uint256 delay;
        uint256 gasPriceCeil;
        uint256 lastExecutionTime;
    }

    bytes public constant HINT = "";
    uint256 public constant PLATFORM_FEE_BPS = 8;

    ISmartWalletSwapImplementation public immutable smartWalletSwap;
    IUniswapV2Router02 public immutable uniRouterV2;
    IUniswapV2Router02 public immutable sushiRouterV2;
    address payable public immutable platformWallet;

    event LogTaskSubmitted(uint256 indexed taskId, Order order);
    event LogTaskCanceled(uint256 indexed taskId, Order order);

    constructor(
        ISmartWalletSwapImplementation _smartWalletSwap,
        IUniswapV2Router02 _uniRouterV2,
        IUniswapV2Router02 _sushiRouterV2,
        address payable _platformWallet,
        address gelatoAddressStorage
    ) public ServicePostExecFee(gelatoAddressStorage) {
        smartWalletSwap = _smartWalletSwap;
        platformWallet = _platformWallet;
        uniRouterV2 = _uniRouterV2;
        sushiRouterV2 = _sushiRouterV2;
    }

    function submit(
        address inToken,
        address outToken,
        uint256 amountPerTrade,
        uint256 nTradesLeft,
        uint256 minSlippage,
        uint256 maxSlippage,
        uint256 delay,
        uint256 gasPriceCeil
    ) external payable {
        if (inToken == _ETH) {
            require(
                msg.value == amountPerTrade.mul(nTradesLeft),
                "GelatoKrystal: mismatching amount of ETH deposited"
            );
        }
        Order memory order = Order({
            user: msg.sender,
            inToken: inToken,
            outToken: outToken,
            amountPerTrade: amountPerTrade,
            nTradesLeft: nTradesLeft,
            minSlippage: minSlippage,
            maxSlippage: maxSlippage,
            delay: delay,
            gasPriceCeil: gasPriceCeil,
            lastExecutionTime: block.timestamp
        });

        // store order
        _storeOrder(order, msg.sender);
    }

    function cancel(Order calldata _order, uint256 _id) external {
        _removeTask(abi.encode(_order), _id, msg.sender);
        if (_order.inToken == _ETH) {
            uint256 refundAmount = _order.amountPerTrade.mul(
                _order.nTradesLeft
            );
            _order.user.call{value: refundAmount, gas: 2300}("");
        }

        emit LogTaskCanceled(_id, _order);
    }

    function execUniOrSushi(
        Order calldata _order,
        uint256 _id,
        address[] calldata _uniswapTradePath,
        bool isUni
    ) external gelatofy(_order.outToken, _order.user, abi.encode(_order), _id) {
        // action exec
        _actionUniOrSushi(_order, _uniswapTradePath, isUni);

        // task cycle logic
        if (_order.nTradesLeft > 0) _updateAndSubmitNextTask(_order);
    }

    function execKyber(Order calldata _order, uint256 _id)
        external
        gelatofy(_order.outToken, _order.user, abi.encode(_order), _id)
    {
        // action exec
        _actionKyber(_order);

        // task cycle logic
        if (_order.nTradesLeft > 0) _updateAndSubmitNextTask(_order);
    }

    function isTaskSubmitted(Order calldata _order, uint256 _id)
        external
        view
        returns (bool)
    {
        return verifyTask(abi.encode(_order), _id, _order.user);
    }

    function getMinReturn(Order memory _order)
        public
        view
        returns (uint256 minReturn)
    {
        // 4. Rate Check
        (uint256 idealReturn, ) = IOracleAggregator(gelatoAS.oracleAggregator())
            .getExpectedReturnAmount(
            _order.amountPerTrade,
            _order.inToken,
            _order.outToken
        );

        // check time (reverts if block.timestamp is below execTime)
        // solhint-disable-next-line not-rely-on-time
        uint256 timeSinceCanExec = block.timestamp.sub(
            _order.lastExecutionTime.add(_order.delay)
        );

        uint256 slippage;
        if (_order.minSlippage > timeSinceCanExec) {
            slippage = _order.minSlippage.sub(timeSinceCanExec);
        }

        if (_order.maxSlippage > slippage) {
            slippage = _order.maxSlippage;
        }

        minReturn = idealReturn.sub(idealReturn.mul(slippage).div(10000));
    }

    // ############# PRIVATE #############
    function _actionKyber(Order memory _order) private {
        //uint256 startGas = gasleft();
        (uint256 ethToSend, uint256 minReturn) = _preExec(_order);
        //console.log("Gas Used in getMinReturn: %s", startGas.sub(gasleft()));
        //startGas = gasleft();

        smartWalletSwap.swapKyber{value: ethToSend}(
            IERC20Ext(_order.inToken),
            IERC20Ext(_order.outToken),
            _order.amountPerTrade,
            minReturn.div(_order.amountPerTrade),
            address(this),
            PLATFORM_FEE_BPS,
            platformWallet,
            HINT,
            false
        );
        //console.log("Gas used in swapKyber: %s", startGas.sub(gasleft()));
    }

    function _actionUniOrSushi(
        Order memory _order,
        address[] memory _uniswapTradePath,
        bool _isUni
    ) private {
        //uint256 startGas = gasleft();
        (uint256 ethToSend, uint256 minReturn) = _preExec(_order);
        //console.log("Gas Used in getMinReturn: %s", startGas.sub(gasleft()));
        //startGas = gasleft();

        require(
            _order.inToken == _uniswapTradePath[0] &&
                _order.outToken ==
                _uniswapTradePath[_uniswapTradePath.length - 1],
            "GelatoKrystal: Uniswap trade path does not match order."
        );
        smartWalletSwap.swapUniswap{value: ethToSend}(
            _isUni ? uniRouterV2 : sushiRouterV2,
            _order.amountPerTrade,
            minReturn,
            _uniswapTradePath,
            address(this),
            PLATFORM_FEE_BPS,
            platformWallet,
            false,
            false
        );

        //console.log("Gas used in swapKyber: %s", startGas.sub(gasleft()));
    }

    function _preExec(Order memory _order)
        private
        returns (uint256 ethToSend, uint256 minReturn)
    {
        if (_order.inToken != _ETH) {
            IERC20Ext(_order.inToken).safeTransferFrom(
                _order.user,
                address(this),
                _order.amountPerTrade
            );
            IERC20Ext(_order.inToken).safeApprove(
                address(smartWalletSwap),
                _order.amountPerTrade
            );
        } else {
            ethToSend = _order.amountPerTrade;
        }
        //uint256 startGas = gasleft();
        minReturn = getMinReturn(_order);
    }

    function _updateAndSubmitNextTask(Order memory _order) private {
        // update next order
        _order.nTradesLeft = _order.nTradesLeft.sub(1);
        _order.lastExecutionTime = block.timestamp;

        _storeOrder(_order, _order.user);
    }

    function _storeOrder(Order memory _order, address _user) private {
        uint256 id = _storeTask(abi.encode(_order), _user);
        emit LogTaskSubmitted(id, _order);
    }

    // ############# Fallback #############
    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}