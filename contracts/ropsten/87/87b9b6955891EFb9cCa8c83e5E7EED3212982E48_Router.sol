//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Pool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Router {
    using SafeERC20 for IERC20;
    IERC20 baseToken;
    mapping(IERC20 => Pool) public pools;
    IERC20[] public tokens;

    constructor(IERC20 _baseToken) {
        baseToken = _baseToken;
    }

    function createPool(
        IERC20 token,
        uint256 liquidityFee,
        uint256 initialBaseTokenAmount,
        uint256 initialTokenAmount,
        string memory name,
        string memory symbol
    ) public {
        baseToken.safeTransferFrom(
            msg.sender,
            address(this),
            initialBaseTokenAmount
        );
        token.safeTransferFrom(msg.sender, address(this), initialTokenAmount);
        Pool pool = new Pool(baseToken, token, liquidityFee, name, symbol);
        token.approve(address(pool), type(uint256).max);
        baseToken.approve(address(pool), type(uint256).max);
        pool.createPool(initialBaseTokenAmount, initialTokenAmount);
        pools[token] = pool;
        tokens.push(token);
    }

    function swap(Pool inputPool, Pool outputPool, uint256 inputAmount) public {
        inputPool.token().safeTransferFrom(
            msg.sender,
            address(this),
            inputAmount
        );
        inputPool.sell(inputAmount);
        outputPool.buy(baseToken.balanceOf(address(this)));
        outputPool.token().safeTransfer(
            msg.sender,
            outputPool.token().balanceOf(address(this))
        );
    }
}