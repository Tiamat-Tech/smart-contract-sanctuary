// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

contract Token is ERC20 {

    IUniswapV2Router02 constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public uniswapV2Pair;

    constructor () payable ERC20("Token", "TKN") {
        _mint(msg.sender, 1000000000 * (10 ** uint256(decimals())));

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
            
        _approve(address(this),address(uniswapV2Router), ~uint256(0));    
        
        _transfer(msg.sender,address(this),totalSupply()/50);

        //addLiquidity(totalSupply()/100, msg.value);    
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) public {
        

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, 
            0, 
            address(0xdead),
            block.timestamp
        );
    }
}