// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/AutomatedExternalReflector.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract DynaAutoEthDistributorV1 is AutomatedExternalReflector {

    event UpdateRouter(address indexed newAddress, address indexed oldAddress);

    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() payable {
        _owner = msg.sender;
        currentRound = 1;
        totalEthDeposits = address(this).balance;
        currentQueueIndex = 0;
        totalRewardsSent = 0;
        totalExcludedTokenHoldings = 0;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Uniswap V2 Routers (Mainnet and Ropsten)
        uniswapV2Router = _uniswapV2Router;
        maxGas = 600000;
        minGas = 50000;
        maxReflectionsPerRound = 100;
        timeBetweenRounds = 1 minutes;
        nextRoundStart = block.timestamp + 1 minutes;

        allowLowLevelCalls = false;
        reflectionsEnabled = true;

        _excludeFromReflections(address(_uniswapV2Router), true);
        _excludeFromReflections(address(this), true);
        _excludeFromReflections(deadAddress, true);

        totalCirculatingTokens = 1 * 10 ** 12 * 10 ** 18;
    }

    function updateRouter(address newAddress, bool andPair) public onlyOwner (){

        emit UpdateRouter(newAddress, address(uniswapV2Router));

        uniswapV2Router = IUniswapV2Router02(newAddress);
        _excludeFromReflections(newAddress, true);

        if(andPair){
            address uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(tokenContract), uniswapV2Router.WETH());
            _excludeFromReflections(uniswapV2Pair, true);
        }
    }
}