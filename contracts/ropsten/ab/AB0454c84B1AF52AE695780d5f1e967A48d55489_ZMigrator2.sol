// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IZetaERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IRouter {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// ZMigrator2 helps your migrate your existing Uniswap and Sushiswap LP tokens to ZetaSwap LP ones
contract ZMigrator2 {
    using SafeERC20 for IERC20;
    IFactory public uniFactory = IFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    IRouter public uniRouter = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IFactory public sushiFactory = IFactory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);
    IRouter public sushiRouter = IRouter(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IRouter public zetaRouter = IRouter(0xDbB2519F39af04d2583D0b6257710C9E0BcD7C28);


    /*
    constructor(
         address _uniFactory,
         address _uniRouter,
         address _sushiFactory,
         address _sushiRouter,
         address _zetaRouter
     ) public {
         uniFactory = IFactory(_uniFactory);
         uniRouter = IRouter(_uniRouter);
         sushiFactory = IFactory(_sushiFactory);
         sushiRouter = IRouter(_sushiRouter);
         zetaRouter = IRouter(_zetaRouter);
     }
   */
      function migrateUniswapWithPermit(
        address token0,
        address token1,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        address pair = uniFactory.getPair(token0, token1);

        // Permit
        IZetaERC20(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );

        _migrate(uniRouter, IZetaERC20(pair), token0, token1, value);
    }

    function migrateSushiSwapWithPermit(
        address token0,
        address token1,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        address pair = sushiFactory.getPair(token0, token1);

        // Permit
        IZetaERC20(pair).permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );

        _migrate(sushiRouter, IZetaERC20(pair), token0, token1, value);
    }

    function migrateUniswap(address token0, address token1, uint256 value) public {
        address pair = uniFactory.getPair(token0, token1);
        _migrate(uniRouter, IZetaERC20(pair), token0, token1, value);
    }

    function migrateSushiSwap(address token0, address token1, uint256 value) public {
        address pair = sushiFactory.getPair(token0, token1);
        _migrate(sushiRouter, IZetaERC20(pair), token0, token1, value);
    }

    function _migrate(IRouter router, IZetaERC20 pair, address token0, address token1, uint256 value) internal {
        // Removes liquidity
        pair.transferFrom(msg.sender, address(this), value);
        pair.approve(address(router), value);
        router.removeLiquidity(
            token0,
            token1,
            value,
            0,
            0,
            address(this),
            now + 60
        );

        // Adds liquidity to ZetaSwap
        uint256 bal0 = IZetaERC20(token0).balanceOf(address(this));
        uint256 bal1 = IZetaERC20(token1).balanceOf(address(this));
        IZetaERC20(token0).approve(address(zetaRouter), bal0);
        IZetaERC20(token1).approve(address(zetaRouter), bal1);
        zetaRouter.addLiquidity(
            token0,
            token1,
            bal0,
            bal1,
            0,
            0,
            msg.sender,
            now + 60
        );

        // Refund sender any remaining tokens
        uint256 remainBal0 = IZetaERC20(token0).balanceOf(address(this));
        uint256 remainBal1 = IZetaERC20(token1).balanceOf(address(this));
        if (remainBal0 > 0) IZetaERC20(token0).transfer(msg.sender, remainBal0);
        if (remainBal1 > 0) IZetaERC20(token1).transfer(msg.sender, remainBal1);
    }
}