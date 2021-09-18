//SPDX-License-Identifier: Unlicense
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "./uniswap/Math.sol";

contract ApeBlenderImpl is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public apeFeeBps;
    address payable public feeTreasury;
    IWETH public wNative;
    IUniswapV2Router02 public exchangeRouter;
    uint256 public exchangeSwapFeeNumerator; // 3 for Uniswap, 25 for Pancakeswap
    uint256 public exchangeSwapFeeDenominator; // 1000 for Uniswap, 10000 for Pancakeswap
    uint256 MAX;

    constructor(
        uint256 _apeFeeBps,
        address payable _feeTreasury,
        address _exchangeRouter,
        address _wNative,
        uint256 _exchangeSwapFeeNumerator,
        uint256 _exchangeSwapFeeDenominator
    ) public {
        apeFeeBps = _apeFeeBps;
        feeTreasury = _feeTreasury;
        exchangeRouter = IUniswapV2Router02(_exchangeRouter);
        wNative = IWETH(_wNative);
        exchangeSwapFeeNumerator = _exchangeSwapFeeNumerator;
        exchangeSwapFeeDenominator = _exchangeSwapFeeDenominator;
        MAX = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    }

    receive() external payable {}

    struct InputToken {
        address token;
        uint256 amount;
        address[] tokenToNativePath;
    }

    struct InputLP {
        address token;
        uint256 amount;
        address[] token0ToNativePath;
        address[] token1ToNativePath;
    }

    function transferNativeFeeToTreasury(uint256 amount)
        private
        returns (uint256)
    {
        if (apeFeeBps == 0) {
            return amount;
        }
        uint256 fee = apeFeeBps.mul(amount).div(10000);
        TransferHelper.safeTransferETH(feeTreasury, fee);
        return amount.sub(fee);
    }

    function transferTokenFeeToTreasury(address token, uint256 amount)
        private
        returns (uint256)
    {
        if (apeFeeBps == 0) {
            return amount;
        }
        uint256 fee = apeFeeBps.mul(amount).div(10000);
        IERC20(token).safeTransfer(feeTreasury, fee);
        return amount.sub(fee);
    }

    function swapTokensToNative(
        InputToken[] memory inputTokens,
        InputLP[] memory inputLPs,
        uint256 minOutputAmount
    ) public payable {
        if (inputLPs.length > 0) {
            _transferTokensToApe(inputLPs);
            _swapTokensForWNative(_removeLiquidity(inputLPs));
        }
        if (inputTokens.length > 0) {
            _transferTokensToApe(inputTokens);
            _swapTokensForWNative(inputTokens);
        }
        uint256 wNativeBalance = wNative.balanceOf(address(this));
        wNative.withdraw(wNativeBalance);
        uint256 amountOut = wNativeBalance.add(msg.value);
        amountOut = transferNativeFeeToTreasury(amountOut);
        require(
            amountOut >= minOutputAmount,
            "Expect amountOut to be greater than minOutputAmount."
        );
        TransferHelper.safeTransferETH(msg.sender, amountOut);
    }

    function swapTokensToToken(
        InputToken[] memory inputTokens,
        InputLP[] memory inputLPs,
        address[] memory nativeToOutputPath,
        uint256 minOutputAmount
    ) public payable {
        if (msg.value > 0) {
            wNative.deposit{value: msg.value}();
        }
        if (inputLPs.length > 0) {
            _transferTokensToApe(inputLPs);
            _swapTokensForWNative(_removeLiquidity(inputLPs));
        }
        if (inputTokens.length > 0) {
            _transferTokensToApe(inputTokens);
            _swapTokensForWNative(inputTokens);
        }
        uint256 wNativeBalance = wNative.balanceOf(address(this));
        uint256 amountOut = _swapWNativeForToken(
            wNativeBalance,
            nativeToOutputPath
        );
        amountOut = transferTokenFeeToTreasury(
            nativeToOutputPath[nativeToOutputPath.length - 1],
            amountOut
        );
        require(
            amountOut >= minOutputAmount,
            "Expect amountOut to be greater than minOutputAmount."
        );
        IERC20(nativeToOutputPath[nativeToOutputPath.length - 1]).safeTransfer(
            msg.sender,
            amountOut
        );
    }

    function swapTokensToLP(
        InputToken[] memory inputTokens,
        InputLP[] memory inputLPs,
        address[] memory nativeToToken0Path,
        address[] memory nativeToToken1Path,
        address outputLP,
        uint256 minOutputAmount
    ) public payable {
        address token0 = IUniswapV2Pair(outputLP).token0();
        address token1 = IUniswapV2Pair(outputLP).token1();
        if (msg.value > 0) {
            wNative.deposit{value: msg.value}();
        }
        if (inputLPs.length > 0) {
            _transferTokensToApe(inputLPs);
            _swapTokensForWNativeExcept(
                _removeLiquidity(inputLPs),
                token0,
                token1
            );
        }
        if (inputTokens.length > 0) {
            _transferTokensToApe(inputTokens);
            _swapTokensForWNativeExcept(inputTokens, token0, token1);
        }
        uint256 wNativeBalance = wNative.balanceOf(address(this));
        _swapWNativeForToken(wNativeBalance.div(2), nativeToToken0Path);
        _swapWNativeForToken(
            wNativeBalance.sub(wNativeBalance.div(2)),
            nativeToToken1Path
        );
        uint256 amountOut = _optimalSwapToLp(
            outputLP,
            token0,
            token1,
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
        amountOut = transferTokenFeeToTreasury(outputLP, amountOut);
        require(
            amountOut >= minOutputAmount,
            "Expect amountOut to be greater than minOutputAmount."
        );
        IERC20(outputLP).safeTransfer(msg.sender, amountOut);
    }

    // Token version
    function _transferTokensToApe(InputToken[] memory inputTokens)
        private
        returns (uint256[] memory)
    {
        uint256[] memory outputAmounts = new uint256[](inputTokens.length);
        for (uint256 i = 0; i < inputTokens.length; i++) {
            IERC20(inputTokens[i].token).safeTransferFrom(
                msg.sender,
                address(this),
                inputTokens[i].amount
            );
            outputAmounts[i] = inputTokens[i].amount;
        }
        return outputAmounts;
    }

    // LP version
    function _transferTokensToApe(InputLP[] memory inputLPs)
        private
        returns (uint256[] memory)
    {
        uint256[] memory outputAmounts = new uint256[](inputLPs.length);
        for (uint256 i = 0; i < inputLPs.length; i++) {
            IERC20(inputLPs[i].token).safeTransferFrom(
                msg.sender,
                address(this),
                inputLPs[i].amount
            );
            outputAmounts[i] = inputLPs[i].amount;
        }
        return outputAmounts;
    }

    function _removeLiquidity(InputLP[] memory inputLPs)
        private
        returns (InputToken[] memory)
    {
        InputToken[] memory outputTokens = new InputToken[](
            inputLPs.length * 2
        );
        for (uint256 i = 0; i < inputLPs.length; i++) {
            IERC20(inputLPs[i].token).approve(address(exchangeRouter), MAX);
            (uint256 amount0, uint256 amount1) = exchangeRouter.removeLiquidity(
                inputLPs[i].token0ToNativePath[0],
                inputLPs[i].token1ToNativePath[0],
                inputLPs[i].amount,
                0,
                0,
                address(this),
                now + 60
            );
            outputTokens[i * 2] = InputToken(
                inputLPs[i].token0ToNativePath[0],
                amount0,
                inputLPs[i].token0ToNativePath
            );
            outputTokens[(i * 2) + 1] = InputToken(
                inputLPs[i].token1ToNativePath[0],
                amount1,
                inputLPs[i].token1ToNativePath
            );
        }
        return outputTokens;
    }

    function _swapTokensForWNative(InputToken[] memory inputTokens)
        private
        returns (uint256)
    {
        uint256 totalNative = 0;
        for (uint256 i = 0; i < inputTokens.length; i++) {
            // Swap non wNative token
            if (inputTokens[i].token != address(wNative)) {
                IERC20(inputTokens[i].token).approve(
                    address(exchangeRouter),
                    MAX
                );
                uint256[] memory amountOuts = exchangeRouter
                    .swapExactTokensForTokens(
                        inputTokens[i].amount,
                        0,
                        inputTokens[i].tokenToNativePath,
                        address(this),
                        now + 60
                    );
                totalNative = totalNative.add(
                    amountOuts[amountOuts.length - 1]
                );
            }
        }
        return totalNative;
    }

    function _swapTokensForWNativeExcept(
        InputToken[] memory inputTokens,
        address token0,
        address token1
    ) private returns (uint256) {
        uint256 totalNative = 0;
        for (uint256 i = 0; i < inputTokens.length; i++) {
            // Skip token0, token1 and wNative
            if (
                inputTokens[i].token != token0 &&
                inputTokens[i].token != token1 &&
                inputTokens[i].token != address(wNative)
            ) {
                IERC20(inputTokens[i].token).approve(
                    address(exchangeRouter),
                    MAX
                );
                uint256[] memory amountOuts = exchangeRouter
                    .swapExactTokensForTokens(
                        inputTokens[i].amount,
                        0,
                        inputTokens[i].tokenToNativePath,
                        address(this),
                        now + 60
                    );
                totalNative = totalNative.add(
                    amountOuts[amountOuts.length - 1]
                );
            }
        }
        return totalNative;
    }

    function _swapWNativeForToken(uint256 amount, address[] memory path)
        private
        returns (uint256)
    {
        if (amount == 0 || path[path.length - 1] == address(wNative)) {
            return amount;
        }
        wNative.approve(address(exchangeRouter), MAX);
        uint256[] memory amountOuts = exchangeRouter.swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            now + 60
        );
        return amountOuts[amountOuts.length - 1];
    }

    function _optimalSwapToLp(
        address outputLP,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) private returns (uint256) {
        IERC20(token0).approve(address(exchangeRouter), MAX);
        IERC20(token1).approve(address(exchangeRouter), MAX);
        (
            uint256 token0Amount,
            uint256 token1Amount
        ) = _optimalSwapForAddingLiquidity(
                outputLP,
                token0,
                token1,
                amount0,
                amount1
            );
        (
            uint256 addedToken0,
            uint256 addedToken1,
            uint256 lpAmount
        ) = exchangeRouter.addLiquidity(
                token0,
                token1,
                token0Amount,
                token1Amount,
                0,
                0,
                address(this),
                now + 60
            );

        // Transfer dust
        if (token0Amount.sub(addedToken0) > 0) {
            IERC20(token0).safeTransfer(
                msg.sender,
                token0Amount.sub(addedToken0)
            );
        }

        if (token1Amount.sub(addedToken1) > 0) {
            IERC20(token1).safeTransfer(
                msg.sender,
                token1Amount.sub(addedToken1)
            );
        }

        return lpAmount;
    }

    function _optimalSwapForAddingLiquidity(
        address lp,
        address token0,
        address token1,
        uint256 token0Amount,
        uint256 token1Amount
    ) private returns (uint256, uint256) {
        (uint256 res0, uint256 res1, ) = IUniswapV2Pair(lp).getReserves();
        if (res0.mul(token1Amount) == res1.mul(token0Amount)) {
            return (token0Amount, token1Amount);
        }

        bool reverse = token0Amount.mul(res1) < token1Amount.mul(res0);

        uint256 optimalSwapAmount = reverse
            ? calculateOptimalSwapAmount(token1Amount, token0Amount, res1, res0)
            : calculateOptimalSwapAmount(
                token0Amount,
                token1Amount,
                res0,
                res1
            );

        address[] memory path = new address[](2);
        (path[0], path[1]) = reverse ? (token1, token0) : (token0, token1);
        if (optimalSwapAmount > 0) {
            uint256[] memory amountOuts = exchangeRouter
                .swapExactTokensForTokens(
                    optimalSwapAmount,
                    0,
                    path,
                    address(this),
                    now + 60
                );
            if (reverse) {
                token0Amount = token0Amount.add(
                    amountOuts[amountOuts.length - 1]
                );
                token1Amount = token1Amount.sub(optimalSwapAmount);
            } else {
                token0Amount = token0Amount.sub(optimalSwapAmount);
                token1Amount = token1Amount.add(
                    amountOuts[amountOuts.length - 1]
                );
            }
        }

        return (token0Amount, token1Amount);
    }

    function calculateOptimalSwapAmount(
        uint256 amtA,
        uint256 amtB,
        uint256 resA,
        uint256 resB
    ) public view returns (uint256) {
        require(
            amtA.mul(resB) >= amtB.mul(resA),
            "Expect amtA value to be greater than amtB value"
        );

        uint256 a = exchangeSwapFeeDenominator.sub(exchangeSwapFeeNumerator);
        uint256 b = uint256(
            exchangeSwapFeeDenominator.mul(2).sub(exchangeSwapFeeNumerator)
        ).mul(resA);
        uint256 _c = (amtA.mul(resB)).sub(amtB.mul(resA));
        uint256 c = _c.mul(exchangeSwapFeeDenominator).div(amtB.add(resB)).mul(
            resA
        );

        uint256 d = a.mul(c).mul(4);
        uint256 e = Math.sqrt(b.mul(b).add(d));

        uint256 numerator = e.sub(b);
        uint256 denominator = a.mul(2);

        return numerator.div(denominator);
    }

    function getWNativeToTokenAmount(
        uint256 wNativeAmount,
        address[] memory nativeToOutputPath
    ) public view returns (uint256) {
        if (wNativeAmount == 0) {
            return 0;
        }
        if (
            nativeToOutputPath[nativeToOutputPath.length - 1] ==
            address(wNative)
        ) {
            uint256 output = wNativeAmount;
            uint256 fee = apeFeeBps.mul(output).div(10000);
            return output.sub(fee);
        }
        uint256[] memory amountOuts = exchangeRouter.getAmountsOut(
            wNativeAmount,
            nativeToOutputPath
        );
        uint256 output = amountOuts[amountOuts.length - 1];
        uint256 fee = apeFeeBps.mul(output).div(10000);
        return output.sub(fee);
    }

    function getWNativeToLpAmount(
        uint256 wNativeAmount,
        address[] memory nativeToToken0Path,
        address[] memory nativeToToken1Path
    ) public view returns (uint256) {
        if (wNativeAmount == 0) {
            return 0;
        }
        address token0 = nativeToToken0Path[nativeToToken0Path.length - 1];
        address token1 = nativeToToken1Path[nativeToToken1Path.length - 1];
        address lp = IUniswapV2Factory(exchangeRouter.factory()).getPair(
            token0,
            token1
        );
        uint256 token0Amount;
        uint256 token1Amount;

        // STEP 1: Swap wNative to token0 and token1
        if (
            nativeToToken0Path[nativeToToken0Path.length - 1] ==
            address(wNative)
        ) {
            token0Amount = wNativeAmount.div(2);
        } else {
            uint256[] memory amountOuts0 = exchangeRouter.getAmountsOut(
                wNativeAmount.div(2),
                nativeToToken0Path
            );
            token0Amount = amountOuts0[amountOuts0.length - 1];
        }

        if (
            nativeToToken1Path[nativeToToken1Path.length - 1] ==
            address(wNative)
        ) {
            token1Amount = wNativeAmount.div(2);
        } else {
            uint256[] memory amountOuts1 = exchangeRouter.getAmountsOut(
                wNativeAmount.div(2),
                nativeToToken1Path
            );
            token1Amount = amountOuts1[amountOuts1.length - 1];
        }

        // STEP 2: Optimal swap for adding liquidity
        (uint256 res0, uint256 res1, ) = IUniswapV2Pair(lp).getReserves();
        if (res0.mul(token1Amount) != res1.mul(token0Amount)) {
            bool reverse = token0Amount.mul(res1) < token1Amount.mul(res0);
            uint256 swapAmount = reverse
                ? calculateOptimalSwapAmount(
                    token1Amount,
                    token0Amount,
                    res1,
                    res0
                )
                : calculateOptimalSwapAmount(
                    token0Amount,
                    token1Amount,
                    res0,
                    res1
                );

            address[] memory swapPath = new address[](2);
            if (reverse) {
                swapPath[0] = token1;
                swapPath[1] = token0;
            } else {
                swapPath[0] = token0;
                swapPath[1] = token1;
            }
            uint256[] memory optimalSwapAmountOuts = exchangeRouter
                .getAmountsOut(swapAmount, swapPath);
            uint256 optimalSwapAmountOut = optimalSwapAmountOuts[
                optimalSwapAmountOuts.length - 1
            ];
            if (reverse) {
                token0Amount = token0Amount.add(optimalSwapAmountOut);
                token1Amount = token1Amount.sub(swapAmount);
                res0 = res0.sub(optimalSwapAmountOut);
                res1 = res1.add(swapAmount);
            } else {
                token0Amount = token0Amount.sub(swapAmount);
                token1Amount = token1Amount.add(optimalSwapAmountOut);
                res0 = res0.add(swapAmount);
                res1 = res1.sub(optimalSwapAmountOut);
            }
        }

        // STEP 3: Calculate lp token output
        uint256 totalSupply = IUniswapV2Pair(lp).totalSupply();
        uint256 outputOptimal0 = token0Amount.mul(totalSupply).div(res0);
        uint256 outputOptimal1 = token1Amount.mul(totalSupply).div(res1);

        uint256 output = outputOptimal0 > outputOptimal1
            ? outputOptimal1
            : outputOptimal0;

        // STEP 4: Calculate fee
        uint256 fee = apeFeeBps.mul(output).div(10000);
        return output.sub(fee);
    }

    function setApeFeeBps(uint256 _apeFeeBps) public onlyOwner {
        apeFeeBps = _apeFeeBps;
    }

    function setFeeTreasury(address _feeTreasury) public onlyOwner {
        feeTreasury = payable(_feeTreasury);
    }

    function setExchange(
        address router,
        uint256 _exchangeSwapFeeNumerator,
        uint256 _exchangeSwapFeeDenominator
    ) public onlyOwner {
        exchangeRouter = IUniswapV2Router02(router);
        exchangeSwapFeeNumerator = _exchangeSwapFeeNumerator;
        exchangeSwapFeeDenominator = _exchangeSwapFeeDenominator;
    }
}