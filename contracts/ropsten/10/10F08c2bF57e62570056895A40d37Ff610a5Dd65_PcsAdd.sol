// SPDX-License-Identifier: GPL-2.0

pragma solidity ^0.8.0;
import "../base/SwapBase.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "../interface/IBKPancake.sol";

interface IWETH {
    function deposit() external payable;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
    external
    view
    returns (address);
}

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
    external
    returns (
        uint256 amountA,
        uint256 amountB,
        uint256 liquidity
    );

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract PcsAdd is SwapBase,IBKPancakeIn{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IUniswapV2Factory private  pancakeswapFactoryAddress;

    IUniswapV2Router02 private  pancakeswapRouter;

    address private  wbnbTokenAddress ;

    uint256 private constant deadline = 0xf000000000000000000000000000000000000000000000000000000000000000;

    constructor(address factory, address router, address wBNB){
        wbnbTokenAddress = wBNB;
        pancakeswapFactoryAddress = IUniswapV2Factory(factory);
        pancakeswapRouter = IUniswapV2Router02(router);
    }

    event zapIn(address sender, address pool, uint256 tokensRec);
    event zapIn01(address sender, address pool, uint256 tokensRec);

    /**
    @notice Add liquidity to Pancakeswap pools with ETH/ERC20 Tokens
    @param _FromTokenContractAddress The ERC20 token used (address(0x00) if ether)
    @param _pairAddress The Pancakeswap pair address
    @param _amount The amount of fromToken to invest
    @param _minPoolTokens Minimum quantity of pool tokens to receive. Reverts otherwise
    @param _swapTarget Excecution target for the first swap
    @param swapData DEX quote data
    @param transferResidual Set false to save gas by donating the residual remaining after a Zap
    @return Amount of LP bought
     */
    function ZapIn(
        address _FromTokenContractAddress,
        address _pairAddress,
        uint256 _amount,
        uint256 _minPoolTokens,
        address _swapTarget,
        bytes calldata swapData,
        bool transferResidual
    ) external override payable stopInEmergency returns (uint256) {
        uint256 LPBought = _performZapIn(_FromTokenContractAddress, _pairAddress, _amount, _swapTarget, swapData, transferResidual);
        require(LPBought >= _minPoolTokens, "High Slippage");
        IERC20(_pairAddress).safeTransfer(msg.sender, LPBought);
        emit zapIn(msg.sender, _pairAddress, LPBought);
        return LPBought;
    }

    function ZapIn01(
        address _pairAddress,
        uint256 amount0,
        uint256 amount1,
        uint256 _minPoolTokens,
        bool transferResidual
    ) external override  stopInEmergency returns (uint256) {
        (address token0, address token1) = _getPairTokens(_pairAddress);
        uint256 LPBought = _uniDeposit(token0, token1, amount0, amount1, transferResidual);
        require(LPBought >= _minPoolTokens, "High Slippage");
        IERC20(_pairAddress).safeTransfer(msg.sender, LPBought);
        emit zapIn01(msg.sender, _pairAddress, LPBought);
        return LPBought;
    }

    function GetAnotherAmount(address token,address pair,uint256 amount) external override  view returns(uint256 another){
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        (uint256 res0, uint256 res1, ) = IUniswapV2Pair(pair).getReserves();
        require(amount > 0, 'pcs_add: INSUFFICIENT_AMOUNT');
        require(res0 > 0 && res1 > 0, 'pcs_add: INSUFFICIENT_LIQUIDITY');
        if( token == token0 ){
            another = amount.mul(res1.div(res0));
        }else if( token == token1 ){
            another = amount.mul(res0.div(res1));
        }
        return another;
    }


    function _performZapIn(
        address _FromTokenContractAddress,
        address _pairAddress,
        uint256 _amount,
        address _swapTarget,
        bytes memory swapData,
        bool transferResidual
    ) internal returns (uint256) {
        uint256 intermediateAmt;
        address intermediateToken;
        (address _ToUniswapToken0, address _ToUniswapToken1) = _getPairTokens(_pairAddress);
        if (_FromTokenContractAddress != _ToUniswapToken0 && _FromTokenContractAddress != _ToUniswapToken1) {
            // swap to intermediate
            (intermediateAmt, intermediateToken) = _fillQuote(_FromTokenContractAddress, _pairAddress, _amount, _swapTarget, swapData);
        } else {
            intermediateToken = _FromTokenContractAddress;
            intermediateAmt = _amount;
        }

        // divide intermediate into appropriate amount to add liquidity
        (uint256 token0Bought, uint256 token1Bought) = _swapIntermediate(intermediateToken, _ToUniswapToken0, _ToUniswapToken1, intermediateAmt);

        return _uniDeposit(_ToUniswapToken0, _ToUniswapToken1, token0Bought, token1Bought, transferResidual);
    }

    function _uniDeposit(
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 token0Bought,
        uint256 token1Bought,
        bool transferResidual
    ) internal returns (uint256) {
        _approveToken(_ToUnipoolToken0, address(pancakeswapRouter), token0Bought);
        _approveToken(_ToUnipoolToken1, address(pancakeswapRouter), token1Bought);

        (uint256 amountA, uint256 amountB, uint256 LP) = pancakeswapRouter.addLiquidity(_ToUnipoolToken0, _ToUnipoolToken1, token0Bought, token1Bought, 1, 1, address(this), deadline);

        if (transferResidual) {
            //Returning Residue in token0, if any.
            if (token0Bought.sub(amountA)  > 0) {
                IERC20(_ToUnipoolToken0).safeTransfer(
                    msg.sender,
                    token0Bought.sub(amountA)
                );
            }

            //Returning Residue in token1, if any
            if (token1Bought.sub(amountB)  > 0) {
                IERC20(_ToUnipoolToken1).safeTransfer(msg.sender, token1Bought.sub(amountB));
            }
        }

        return LP;
    }

    function _fillQuote(address _fromTokenAddress, address _pairAddress, uint256 _amount, address _swapTarget, bytes memory swapData) internal returns (uint256 amountBought, address intermediateToken) {
        if (_swapTarget == wbnbTokenAddress) {
            IWETH(wbnbTokenAddress).deposit{ value: _amount }();
            return (_amount, wbnbTokenAddress);
        }

        uint256 valueToSend;
        if (_fromTokenAddress == address(0)) {
            valueToSend = _amount;
        } else {
            _approveToken(_fromTokenAddress, _swapTarget, _amount);
        }

        (address _token0, address _token1) = _getPairTokens(_pairAddress);
        IERC20 token0 = IERC20(_token0);
        IERC20 token1 = IERC20(_token1);
        uint256 initialBalance0 = token0.balanceOf(address(this));
        uint256 initialBalance1 = token1.balanceOf(address(this));

        require(approvedTargets[_swapTarget], "Target not Authorized");
        (bool success, ) = _swapTarget.call{ value: valueToSend }(swapData);
        require(success, "Error Swapping Tokens 1");

        uint256 finalBalance0 =
        token0.balanceOf(address(this)).sub(initialBalance0);
        uint256 finalBalance1 =
        token1.balanceOf(address(this)).sub(initialBalance1);

        if (finalBalance0 > finalBalance1) {
            amountBought = finalBalance0;
            intermediateToken = _token0;
        } else {
            amountBought = finalBalance1;
            intermediateToken = _token1;
        }

        require(amountBought > 0, "Swapped to Invalid Intermediate");
    }

    function _swapIntermediate(
        address _toContractAddress,
        address _ToUnipoolToken0,
        address _ToUnipoolToken1,
        uint256 _amount
    ) internal returns (uint256 token0Bought, uint256 token1Bought) {
        IUniswapV2Pair pair = IUniswapV2Pair(pancakeswapFactoryAddress.getPair(_ToUnipoolToken0, _ToUnipoolToken1));
        (uint256 res0, uint256 res1, ) = pair.getReserves();
        if (_toContractAddress == _ToUnipoolToken0) {
            uint256 amountToSwap = calculateSwapInAmount(res0, _amount);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = _amount.div(2);
            token1Bought = _token2Token(_toContractAddress, _ToUnipoolToken1, amountToSwap);
            token0Bought = _amount.sub(amountToSwap);

        } else {
            uint256 amountToSwap = calculateSwapInAmount(res1, _amount);
            //if no reserve or a new pair is created
            if (amountToSwap <= 0) amountToSwap = _amount.div(2);
            token0Bought = _token2Token(_toContractAddress, _ToUnipoolToken0, amountToSwap);
            token1Bought = _amount.sub(amountToSwap);
        }
    }

    function calculateSwapInAmount(uint256 reserveIn, uint256 userIn)
    internal
    pure
    returns (uint256)
    {

        return SafeMath.sqrt(reserveIn.mul(userIn.mul(3988000) + reserveIn.mul(3988009))).sub(reserveIn.mul(1997)) / 1994;
    }

    /**
    @notice This function is used to swap ERC20 <> ERC20
    @param _FromTokenContractAddress The token address to swap from.
    @param _ToTokenContractAddress The token address to swap to.
    @param tokens2Trade The amount of tokens to swap
    @return tokenBought The quantity of tokens bought
    */
    function _token2Token(
        address _FromTokenContractAddress,
        address _ToTokenContractAddress,
        uint256 tokens2Trade
    ) internal returns (uint256 tokenBought) {
        if (_FromTokenContractAddress == _ToTokenContractAddress) {
            return tokens2Trade;
        }

        _approveToken(_FromTokenContractAddress, address(pancakeswapRouter), tokens2Trade);

        address pair = pancakeswapFactoryAddress.getPair(_FromTokenContractAddress, _ToTokenContractAddress);
        require(pair != address(0), "No Swap Available");
        address[] memory path = new address[](2);
        path[0] = _FromTokenContractAddress;
        path[1] = _ToTokenContractAddress;

        tokenBought = pancakeswapRouter.swapExactTokensForTokens(
            tokens2Trade,
            1,
            path,
            address(this),
            deadline
        )[path.length - 1];

        require(tokenBought > 0, "Error Swapping Tokens 2");
    }

}