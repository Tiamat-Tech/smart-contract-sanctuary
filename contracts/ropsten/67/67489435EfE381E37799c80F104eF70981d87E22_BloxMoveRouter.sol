// SPDX-License-Identifier: GPL-3.0 License

pragma solidity ^0.8.0;

import "./BloxMoveRewardProvider.sol";
import "./interfaces/IBloxMoveRouter.sol";

import "./interfaces/IWETH.sol";

import "./libraries/TransferHelper.sol";


contract BloxMoveRouter is BloxMoveRewardProvider, IBloxMoveRouter {

    address public immutable override WETH;


    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _WETH, address _rewardToken) BloxMoveRewardProvider(_rewardToken) {
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = getReserves(tokenA, tokenB);
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
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address treasury = getTreasury[tokenA][tokenB];
        TransferHelper.safeTransferFrom(tokenA, msg.sender, treasury, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, treasury, amountB);
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
        (amountToken, amountETH) = _addLiquidity(token, WETH, amountTokenDesired, msg.value, amountTokenMin, amountETHMin);
        address treasury = getTreasury[token][WETH];
        TransferHelper.safeTransferFrom(token, msg.sender, treasury, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(treasury, amountETH));
        liquidity = _mint(to, token, WETH, amountToken, amountETH, lockedDays);
        if (msg.value > amountETH) TransferHelper.safeTransferCurrency(msg.sender, msg.value - amountETH); // refund dust, if any
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
        require (getTreasury[tokenA][tokenB] != address(0), 'TREASURY_NOT_FOUND');
        uint amount0;
        uint amount1;
        (amount0, amount1, rewards) = _burn(to, liquidity, idx);
        (address token0,) = BloxMoveLibrary.sortTokens(tokenA, tokenB);
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
        return BloxMoveLibrary.quote(amountA, reserveA, reserveB);
    }
}