// SPDX-License-Identifier: GPL-2.0

pragma solidity ^0.8.0;

import "./base/RouterBase.sol";
import "@pancakeswap/pancake-swap-lib/contracts/utils/TransferHelper.sol";
import "./interface/IBKPancake.sol";

contract SwapV2PoolRouter is  RouterBase {
    using SafeERC20 for IERC20;

    constructor(uint256 _goodwill, uint256 _affiliateSplit)
    RouterBase(_goodwill, _affiliateSplit){}

    /**
    @notice Add liquidity to Pancakeswap pools with ETH/ERC20 Tokens
    @param _addresses[0]  contract address to call   _addresses[1] The ERC20 token used (address(0x00) if ether)   _addresses[2] The Pancakeswap pair address
    @param _amount The amount of fromToken to invest
    @param _minPoolTokens Minimum quantity of pool tokens to receive. Reverts otherwise
    @param _swapTarget Excecution target for the first swap
    @param swapData DEX quote data
    @param affiliate Affiliate address
    @param transferResidual Set false to save gas by donating the residual remaining after a Zap
    @param shouldSellEntireBalance  If True transfers entrire allowable amount from another contract
    @return Amount of LP bought
     */
    function addLiquidity01(
        address[] calldata _addresses,
        uint256 _amount,
        uint256 _minPoolTokens,
        address _swapTarget,
        bytes calldata swapData,
        address affiliate,
        bool transferResidual,
        bool shouldSellEntireBalance
    ) external payable stopInEmergency returns (uint256) {
        require(_addresses.length == 3,"_addresses.length is not 3");
        uint256 toInvest = _pullTokens(_addresses[1], _amount, affiliate, true, shouldSellEntireBalance);
        if (_addresses[1]  != address(0)) {
            IERC20(_addresses[1]).safeTransfer(_addresses[0],toInvest);
        }
        uint256 LPBought = IBKPancakeIn(_addresses[0]).ZapIn(_addresses[1],_addresses[2],toInvest,_minPoolTokens,_swapTarget,swapData,transferResidual);
        IERC20(_addresses[2]).safeTransfer(msg.sender, LPBought);
        return LPBought;
    }

    /**
    @notice Add liquidity to Pancakeswap pools with two lp token
    @param _contractAddress  contract address to call
    @param _pairAddress The Pancakeswap pair address
    @param _amount0 The amount of fromToken to invest
    @param _amount1 The amount of fromToken to invest
    @param _minPoolTokens Minimum quantity of pool tokens to receive. Reverts otherwise
    @param affiliate Affiliate address
    @param transferResidual Set false to save gas by donating the residual remaining after a Zap
    @param shouldSellEntireBalance  If True transfers entrire allowable amount from another contract
    @return Amount of LP bought
     */
    function addLiquidity02(
        address _contractAddress,
        address _pairAddress,
        uint256 _amount0,
        uint256 _amount1,
        uint256 _minPoolTokens,
        address affiliate,
        bool transferResidual,
        bool shouldSellEntireBalance
    ) external  stopInEmergency returns (uint256) {
        (uint256 token0Bought,uint256 token1Bought) = _pullBothTokens(_amount0, _amount1, _pairAddress, affiliate, shouldSellEntireBalance);
        ( address token0, address token1) = _getPairTokens(_pairAddress);
        IERC20(token0).safeTransfer(_contractAddress,token0Bought);
        IERC20(token1).safeTransfer(_contractAddress,token1Bought);
        uint256 LPBought = IBKPancakeIn(_contractAddress).ZapIn01( _pairAddress, token0Bought,token1Bought, _minPoolTokens, transferResidual);
        IERC20(_pairAddress).safeTransfer(msg.sender, LPBought);
        return LPBought;
    }

//     **** REMOVE LIQUIDITY 02 ****
    function removeLiquidity02(
        address _contractAddress,
        address fromPoolAddress,
        uint256 incomingLP,
        address affiliate
    ) public stopInEmergency returns (uint amountA, uint amountB) {
        IUniswapV2Pair pair = IUniswapV2Pair(fromPoolAddress);
        require(address(pair) != address(0), "Pool Cannot be Zero Address");
        require(address(_contractAddress) != address(0), "Router Cannot be Zero Address");
        address token0 = pair.token0();
        address token1 = pair.token1();

        IERC20(fromPoolAddress).safeTransferFrom(msg.sender, address(this), incomingLP);
        address nativeToken = IBKPancakeOut(_contractAddress).getNativeToken();
        if (token0 == nativeToken || token1 == nativeToken) {
            address _token = token0 == nativeToken ? token1 : token0;
            ( amountA,  amountB)= IBKPancakeOut(_contractAddress).ZapOut2PairToken(fromPoolAddress, incomingLP);
            // subtract goodwill
            uint256 tokenGoodwill = _subtractGoodwill(_token, amountA, affiliate, true);
            uint256 ethGoodwill = _subtractGoodwill(ETHAddress, amountB, affiliate, true);
            // send tokens
            IERC20(_token).safeTransfer(msg.sender, amountA - tokenGoodwill);
            Address.sendValue(payable(msg.sender), amountB - ethGoodwill);
        } else {
            ( amountA,  amountB)= IBKPancakeOut(_contractAddress).ZapOut2PairToken(fromPoolAddress, incomingLP);
            // subtract goodwill
            uint256 tokenAGoodwill = _subtractGoodwill(token0, amountA, affiliate, true);
            uint256 tokenBGoodwill = _subtractGoodwill(token1, amountB, affiliate, true);
            // send tokens
            IERC20(token0).safeTransfer(msg.sender, amountA - tokenAGoodwill);
            IERC20(token1).safeTransfer(msg.sender, amountB - tokenBGoodwill);
        }
    }

    //     **** REMOVE LIQUIDITY 01 ****
    function removeLiquidity01(
        address _contractAddress,
        address toTokenAddress,
        address fromPoolAddress,
        uint256 incomingLP,
        uint256 minTokensRec,
        address[] memory swapTargets,
        bytes[] memory swapData,
        address affiliate,
        bool shouldSellEntireBalance
    ) public stopInEmergency returns (uint256 tokensRec) {
        uint256 amountLP = _pullTokens( fromPoolAddress, incomingLP, shouldSellEntireBalance);
        IERC20(fromPoolAddress).safeTransfer( _contractAddress, amountLP);
        tokensRec = IBKPancakeOut(_contractAddress).ZapOut( toTokenAddress, fromPoolAddress, amountLP, minTokensRec, swapTargets, swapData);
        uint256 totalGoodwillPortion;
        // transfer toTokens to sender
        if (toTokenAddress == address(0)) {
            totalGoodwillPortion = _subtractGoodwill( ETHAddress, tokensRec, affiliate, true);
            payable(msg.sender).transfer(tokensRec - totalGoodwillPortion);
        } else {
            totalGoodwillPortion = _subtractGoodwill( toTokenAddress, tokensRec, affiliate, true);
            IERC20(toTokenAddress).safeTransfer( msg.sender, tokensRec - totalGoodwillPortion);
        }

        tokensRec = tokensRec - totalGoodwillPortion;
    }

}