// SPDX-License-Identifier: GPL-3.0 License

pragma solidity ^0.8.0;

import "./BLXMRewardProvider.sol";
import "./interfaces/IBLXMRouter.sol";

import "./interfaces/IWETH.sol";

import "./libraries/TransferHelper.sol";
import "./libraries/BLXMLibrary.sol";


contract BLXMRouter is BLXMRewardProvider, IBLXMRouter {

    address public override WETH;


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    receive() external payable {
        assert(_msgSender() == WETH); // only accept ETH via fallback from the WETH contract
    }

    function initialize(address _WETH, address _TREASURY_MANAGER) public initializer {
        WETH = _WETH;
        __BLXMRewardProvider_init(_TREASURY_MANAGER);
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address treasury,
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = BLXMLibrary.getReserves(treasury, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint16 lockedDays
    ) external override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        address treasury = BLXMLibrary.getTreasury(TREASURY_MANAGER, tokenA, tokenB);
        (amountA, amountB) = _addLiquidity(treasury, tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        TransferHelper.safeTransferFrom(tokenA, _msgSender(), address(this), amountA);
        TransferHelper.safeTransferFrom(tokenB, _msgSender(), address(this), amountB);
        TransferHelper.safeTransfer(tokenA, treasury, amountA);
        TransferHelper.safeTransfer(tokenB, treasury, amountB);
        liquidity = _mint(to, tokenA, tokenB, amountA, amountB, lockedDays);
    }

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint16 lockedDays
    ) external override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        address treasury = BLXMLibrary.getTreasury(TREASURY_MANAGER, token, WETH);
        (amountToken, amountETH) = _addLiquidity(treasury, token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        TransferHelper.safeTransferFrom(token, _msgSender(), address(this), amountToken);
        TransferHelper.safeTransfer(token, treasury, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(treasury, amountETH));
        liquidity = _mint(to, token, WETH, amountToken, amountETH, lockedDays);
        if (msg.value > amountETH) TransferHelper.safeTransferCurrency(_msgSender(), msg.value - amountETH); // refund dust, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        uint idx
    ) public override ensure(deadline) returns (uint amountA, uint amountB, uint rewards) {
        require(BLXMLibrary.getTreasury(TREASURY_MANAGER, tokenA, tokenB) != address(0), 'TREASURY_NOT_FOUND');
        uint amount0;
        uint amount1;
        (amount0, amount1, rewards) = _burn(to, liquidity, idx);
        (address token0,) = BLXMLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
    }
    
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        uint idx
    ) public override ensure(deadline) returns (uint amountToken, uint amountETH, uint rewards) {
        (amountToken, amountETH, rewards) = removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin, address(this), deadline, idx);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferCurrency(to, amountETH);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure override returns (uint amountB) {
        return BLXMLibrary.quote(amountA, reserveA, reserveB);
    }
}