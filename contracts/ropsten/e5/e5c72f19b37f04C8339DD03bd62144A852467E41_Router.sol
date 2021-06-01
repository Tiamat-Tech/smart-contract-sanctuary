//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Router {
    using SafeERC20 for IERC20;
    IERC20 baseToken;
    Pool[] public pools;
    mapping(Pool => uint112) public baseTokenBalances;
    mapping(Pool => uint256) public tokenBalances;

    constructor(IERC20 _baseToken) {
        baseToken = _baseToken;
    }

    function convert(
        Pool inputPool,
        Pool outputPool,
        uint256 inputAmount
    ) public {
        uint256 gasBefore = gasleft();
        uint256 baseTokenAmount =
            calculateOutputAmount(
                inputPool,
                tokenBalances[inputPool],
                baseTokenBalances[inputPool],
                inputAmount
            );
        chargeToken(inputPool, inputAmount);
        payToken(
            outputPool,
            calculateOutputAmount(
                outputPool,
                baseTokenBalances[outputPool],
                tokenBalances[outputPool],
                baseTokenAmount
            )
        );
        baseTokenBalances[inputPool] -= uint112(baseTokenAmount);
        baseTokenBalances[outputPool] += uint112(baseTokenAmount);
        console.log("%s", gasBefore - gasleft());
    }

    function createPool(
        IERC20 token,
        uint256 liquidityFee,
        uint256 initialBaseTokenAmount,
        uint256 initialTokenAmount,
        string memory name,
        string memory symbol
    ) public {
        Pool pool = new Pool(baseToken, token, liquidityFee, name, symbol);
        chargeBaseToken(pool, initialBaseTokenAmount);
        chargeToken(pool, initialTokenAmount);
        pool.mint(msg.sender, initialTokenAmount);
        pools.push(pool);
    }

    function addLiquidity(Pool pool, uint256 inputAmount) public {
        pool.mint(
            msg.sender,
            proportionOf(inputAmount, pool.totalSupply(), tokenBalances[pool])
        );
        chargeBaseToken(
            pool,
            proportionOf(
                inputAmount,
                baseTokenBalances[pool],
                tokenBalances[pool]
            )
        );
        chargeToken(pool, inputAmount);
    }

    function removeLiquidity(Pool pool, uint256 percentageToBurn) public {
        uint256 baseTokenToRemove =
            proportionOf(
                baseTokenBalances[pool],
                proportionOf(
                    pool.balanceOf(msg.sender),
                    percentageToBurn,
                    1 ether
                ),
                pool.totalSupply()
            );
        payBaseToken(pool, baseTokenToRemove);
        uint256 tokenToRemove =
            proportionOf(
                tokenBalances[pool],
                proportionOf(
                    pool.balanceOf(msg.sender),
                    percentageToBurn,
                    1 ether
                ),
                pool.totalSupply()
            );
        payToken(pool, tokenToRemove);
        /* pool.token().safeTransfer(msg.sender, tokenToRemove); */
        /* tokenBalances[pool] -= tokenToRemove; */
        pool.burn(
            msg.sender,
            proportionOf(pool.balanceOf(msg.sender), percentageToBurn, 1 ether)
        );
    }

    function buy(Pool pool, uint256 inputAmount) public {
        payToken(
            pool,
            calculateOutputAmount(
                pool,
                baseTokenBalances[pool],
                tokenBalances[pool],
                inputAmount
            )
        );
        chargeBaseToken(pool, inputAmount);
    }

    function payToken(Pool pool, uint256 amount) public {
        uint256 gasBefore = gasleft();
        pool.token().safeTransfer(msg.sender, amount);
        tokenBalances[pool] -= amount;
        console.log("payToken %s", gasBefore - gasleft());
    }

    function chargeToken(Pool pool, uint256 amount) public {
        uint256 gasBefore = gasleft();
        pool.token().safeTransferFrom(msg.sender, address(this), amount);
        tokenBalances[pool] += amount;
        console.log("chargeToken %s", gasBefore - gasleft());
    }

    function payBaseToken(Pool pool, uint256 amount) public {
        baseTokenBalances[pool] -= uint112(amount);
        baseToken.safeTransfer(msg.sender, amount);
    }

    function chargeBaseToken(Pool pool, uint256 amount) public {
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        baseTokenBalances[pool] += uint112(amount);
    }

    function sell(Pool pool, uint256 inputAmount) public {
        baseToken.safeTransfer(
            msg.sender,
            calculateOutputAmount(
                pool,
                tokenBalances[pool],
                baseTokenBalances[pool],
                inputAmount
            )
        );
        baseTokenBalances[pool] += uint112(inputAmount);
        pool.token().safeTransferFrom(msg.sender, address(this), inputAmount);
        tokenBalances[pool] -= inputAmount;
    }

    function calculateOutputAmount(
        Pool pool,
        uint256 inputSupply,
        uint256 outputSupply,
        uint256 inputAmount
    ) internal view returns (uint256) {
        return
            outputSupply -
            (inputSupply * outputSupply) /
            (inputSupply +
                (inputAmount - (inputAmount * pool.liquidityFee()) / 1 ether));
    }

    function proportionOf(
        uint256 value,
        uint256 x,
        uint256 y
    ) internal pure returns (uint256) {
        return ((value * x) / y);
    }
}