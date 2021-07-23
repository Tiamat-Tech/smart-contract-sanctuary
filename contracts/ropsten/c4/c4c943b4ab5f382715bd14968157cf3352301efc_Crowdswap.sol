// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interface/ICrowdswap.sol";
import "./interface/IUniswapV2Router02.sol";
import "./interface/IBalancerExchangeProxy.sol";
import "./interface/IBancorNetwork.sol";
import "./interface/IKyberNetworkProxy.sol";
import "./helpers/UniERC20.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract Crowdswap is ICrowdswap {

    using SafeMath for uint256;
    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    uint256 percentage = 1;

    IUniswapV2Router02 private constant uniswapV2Router02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IUniswapV2Router02 private constant sushiswapV2Router02 = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IBancorContractRegistry private constant bancorContractRegistry = IBancorContractRegistry(0xFD95E724962fCfC269010A0c6700Aa09D5de3074);
    //    0x52Ae12ABe5D8BD778BD5397F99cA900624CfADD4, main
    //    0xFD95E724962fCfC269010A0c6700Aa09D5de3074 ropsten

    IBalancerExchangeProxy private constant balancerExchangeProxy = IBalancerExchangeProxy(0x4e67bf5bD28Dd4b570FBAFe11D0633eCbA2754Ec);
    //    0x3E66B66Fd1d0b02fDa6C811Da9E0547970DB2f21, main
    //    0x4e67bf5bD28Dd4b570FBAFe11D0633eCbA2754Ec kovan

    IKyberNetworkProxy private constant kyberNetworkProxy = IKyberNetworkProxy(0xd719c34261e099Fdb33030ac8909d5788D3039C4);
    //    0x9AAb3f75489902f3a48495025729a0AF77d4b11e, main
    //    0xd719c34261e099Fdb33030ac8909d5788D3039C4, ropsten
    //    0x0d5371e5EE23dec7DF251A8957279629aa79E9C5, RINKEBY
    //    0xc153eeAD19e0DBbDb3462Dcc2B703cC6D738A37c kovan


    uint8 private constant _UNISWAP = 0x01;
    uint8 private constant _SUSHISWAP = 0x02;
    uint8 private constant _BANCOR = 0x04;
    uint8 private constant _BALANCER = 0x08;
    uint8 private constant _KYBER = 0x10;

    event SwapSucceedEvent(uint256 beforeSwapBalance, uint256 afterSwapBalance, uint256 amountOut, uint256 fee);

    struct SwapDescriptor {
        uint256 amountIn;
        address[] path;
        uint256 amountOutMin;
        uint256 deadline;
    }

    receive() external payable {}

    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        address payable receiver,
        SwapDescriptor calldata desc,
        uint8 dexFlag
    )
    external payable returns (uint256 returnAmount){
        if (fromToken == destToken) {
            return 0;
        }
        require(msg.value == (fromToken.isETH() ? desc.amountIn : 0), "Invalid msg.value");
        uint256 beforeSwapBalance = destToken.uniBalanceOf(address(this));
        //TODO: check if there is enough ETH funds to pay during swap
        address dexAddress = _retrieveDexAddress(dexFlag);
        require(dexAddress != address(0), "The given DEX is not supported");
        fromToken.safeTransferFrom(msg.sender, address(this), desc.amountIn);
        _approve(fromToken, dexAddress, desc.amountIn);

        //TODO: prevent the “sandwich” attack
        uint256[] memory dexResult;
        if (dexFlag & _UNISWAP != 0 || dexFlag & _SUSHISWAP != 0) {
            if (fromToken.isETH()) {
                dexResult = IUniswapV2Router02(dexAddress).swapExactETHForTokens{value : msg.value}(
                    desc.amountOutMin,
                    desc.path,
                    address(this),
                    desc.deadline
                );
            } else if (destToken.isETH()) {
                dexResult = IUniswapV2Router02(dexAddress).swapExactTokensForETH(
                    desc.amountIn,
                    desc.amountOutMin,
                    desc.path,
                    address(this),
                    desc.deadline);
            } else {
                dexResult = IUniswapV2Router02(dexAddress).swapExactTokensForTokens(
                    desc.amountIn,
                    desc.amountOutMin,
                    desc.path,
                    address(this),
                    desc.deadline);
            }
        } else if (dexFlag & _BANCOR != 0) {
            dexResult[0] = IBancorNetwork(dexAddress).convert{value : msg.value}(
                desc.path,
                desc.amountIn,
                desc.amountOutMin);
        } else if (dexFlag & _BALANCER != 0) {
            revert("Swap via balancer is not supported yet");
        } else if (dexFlag & _KYBER != 0) {
            dexResult[0] = IKyberNetworkProxy(dexAddress).tradeWithHintAndFee{value : msg.value}(
                payable(this),
                address(fromToken),
                desc.amountIn,
                address(destToken),
                payable(this),
                desc.amountOutMin,
                0,
                payable(address((0))),
                0,
                '0x'
            );
        }

        uint256 amountOut = uint256(dexResult[dexResult.length - 1]);
        uint256 afterSwapBalance = destToken.uniBalanceOf(address(this));
        uint256 fee = _feeCalculator(amountOut, percentage, 10);
        emit SwapSucceedEvent(beforeSwapBalance, afterSwapBalance, amountOut, fee);
        require(beforeSwapBalance.sub(afterSwapBalance) == amountOut, "There is no sufficient received funds");
        amountOut = amountOut.sub(fee);
        destToken.safeTransfer(receiver, amountOut);

        return amountOut;
    }

    event MyEvent(uint256 result);

    function mySwap(
        IERC20 fromToken,
        IERC20 destToken,
        address payable receiver,
        SwapDescriptor calldata desc,
        uint8 dexFlag
    ) external returns (uint256 result){
        emit MyEvent(1001);
        return 1001;
    }

    function _retrieveDexAddress(uint8 dexFlag) private view returns (address){
        if (dexFlag & _UNISWAP != 0) {
            return address(uniswapV2Router02);
        } else if (dexFlag & _SUSHISWAP != 0) {
            return address(sushiswapV2Router02);
        }
        else if (dexFlag & _BANCOR != 0) {
            return address(bancorContractRegistry);
        }
        else if (dexFlag & _BALANCER != 0) {
            return bancorContractRegistry.addressOf('BancorNetwork');
        }
        else if (dexFlag & _KYBER != 0) {
            return address(kyberNetworkProxy);
        }
        return address(0);
    }

    function _approve(IERC20 token, address dex, uint256 amountIn) private {
        if (token.isETH()) {
            return;
        }
        token.uniApprove(dex, amountIn);
    }

    function _feeCalculator(
        uint256 withdrawalAmount,
        uint256 percentage,
        uint256 fraction
    ) private pure returns (uint256){
        return percentage.mul(withdrawalAmount).div(fraction).div(100);
    }

}