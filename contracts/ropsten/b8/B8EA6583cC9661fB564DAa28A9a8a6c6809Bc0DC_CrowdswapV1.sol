// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "./Crowdswap.sol";
import "./interface/IUniswapV2Router02.sol";
import "./interface/IUniswapV3Router.sol";
import "./interface/IBancorNetwork.sol";
import "./interface/IBalancerExchangeProxy.sol";
import "./interface/IBalancerExchangeProxy.sol";
import "./interface/IKyberNetworkProxy.sol";
import "./helpers/UniERC20.sol";
import "./helpers/Ownable.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdswapV1 is Ownable, Crowdswap {

    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    address private uniswapV2Router02;
    address private uniswapV3Router;
    address private sushiswapV2Router02;
    address private bancorContractRegistry;
    address private balancerExchangeProxy;
    address private kyberNetworkProxy;

    constructor(
        address _uniswap2,
        address _uniswap3,
        address _sushiswap,
        address _balancer,
        address _bancor,
        address _kyber
    ){
        uniswapV2Router02 = _uniswap2;
        uniswapV3Router = _uniswap3;
        sushiswapV2Router02 = _sushiswap;
        balancerExchangeProxy = _balancer;
        bancorContractRegistry = _bancor;
        kyberNetworkProxy = _kyber;
    }

    function setUniswapV2Router02(address uniswapAddress) external onlyOwner {
        require(uniswapAddress != address(0), "ce02");
        uniswapV2Router02 = uniswapAddress;
    }

    function getUniswapV2Router02() public view returns (address){
        return uniswapV2Router02;
    }

    function setSushiswapV2Router02(address sushiAddress) external onlyOwner {
        require(sushiAddress != address(0), "ce02");
        sushiswapV2Router02 = sushiAddress;
    }

    function getSushiswapV2Router02() public view returns (address){
        return sushiswapV2Router02;
    }

    function setBalancerExchangeProxy(address _balancer) external onlyOwner {
        require(_balancer != address(0), "ce02");
        balancerExchangeProxy = _balancer;
    }

    function getBalancerExchangeProxy() public view returns (address){
        return balancerExchangeProxy;
    }

    function setBancorContractRegistry(address _bancor) external onlyOwner {
        require(_bancor != address(0), "ce02");
        bancorContractRegistry = _bancor;
    }

    function getBancorContractRegistry() public view returns (address){
        return bancorContractRegistry;
    }

    function setKyberNetworkProxy(address _kyber) external onlyOwner {
        require(_kyber != address(0), "ce02");
        kyberNetworkProxy = _kyber;
    }

    function getKyberNetworkProxy() public view returns (address){
        return kyberNetworkProxy;
    }

    function swap(
        IERC20 _fromToken,
        IERC20 _destToken,
        address payable _receiver,
        SwapDescriptor calldata _desc,
        uint8 _dexFlag
    )
    external override payable returns (uint256 returnAmount){
        if (_fromToken == _destToken) {
            return 0;
        }
        //TODO: check if there is enough ETH funds to pay during swap
        (uint256 beforeSwappingBalance, address dexAddress) = _prepareSwap(_fromToken, _destToken, _desc.amountIn, _dexFlag);

        //TODO: prevent the “sandwich” attack
        uint256[] memory dexResult;
        if (_dexFlag == _UNISWAPV2 || _dexFlag == _SUSHISWAP) {
            if (_fromToken.isETH()) {
                dexResult = IUniswapV2Router02(dexAddress).swapExactETHForTokens{value : msg.value}(
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline
                );
            } else if (_destToken.isETH()) {
                dexResult = IUniswapV2Router02(dexAddress).swapExactTokensForETH(
                    _desc.amountIn,
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline);
            } else {
                dexResult = IUniswapV2Router02(dexAddress).swapExactTokensForTokens(
                    _desc.amountIn,
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline);
            }
        }
        else if (_dexFlag == _UNISWAPV3) {
            revert("ce99");
        }
        else if (_dexFlag == _BALANCER) {
            revert("ce99");
        }
        else if (_dexFlag == _BANCOR) {
            dexResult = new uint256[](1);
            dexResult[0] = IBancorNetwork(dexAddress).convertByPath{value : msg.value}(
                _desc.path,
                _desc.amountIn,
                _desc.amountOutMin,
                address(0),
                address(0),
                0
            );
        }
        else if (_dexFlag == _KYBER) {
            dexResult = new uint256[](1);
            dexResult[0] = IKyberNetworkProxy(dexAddress).tradeWithHintAndFee{value : msg.value}(
                address(_fromToken),
                _desc.amountIn,
                address(_destToken),
                payable(this),
                _desc.amountOutMin,
                0,
                payable(address(0)),
                0,
                ""
            );
        }

        uint256 amountOut = uint256(dexResult[dexResult.length - 1]);
        amountOut = _augmentSwap(_receiver, _destToken, beforeSwappingBalance, amountOut);

        return amountOut;
    }

    function swapViaUniswapV3(
        IERC20 _fromToken,
        IERC20 _destToken,
        address payable _receiver,
        bytes calldata _path,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint256 _deadline
    )
    external payable returns (uint256 returnAmount){
        if (_fromToken == _destToken) {
            return 0;
        }

        (uint256 _beforeSwappingBalance,address _dexAddress) = _prepareSwap(_fromToken, _destToken, _amountIn, 0x02);

        uint256[] memory dexResult;
        IUniswapV3Router.ExactInputParams memory uni3Params = IUniswapV3Router.ExactInputParams(
            _path,
            address(this),
            _deadline,
            _amountIn,
            _amountOutMin
        );
        uint256 amountOut = IUniswapV3Router(_dexAddress).exactInput(
            uni3Params
        );
        if (_destToken.isETH()) {
            amountOut = IUniswapV3Router(_dexAddress).unwrapWETH9(
                amountOut, address(this)
            );
        }
        amountOut = _augmentSwap(_receiver, _destToken, _beforeSwappingBalance, amountOut);

        return amountOut;
    }

    function swapViaBalancer(
        IERC20 _fromToken,
        IERC20 _destToken,
        address payable _receiver,
        Swap[][] memory _swapSequences,
        uint256 _totalAmountIn,
        uint256 _minTotalAmountOut
    )
    external payable returns (uint256){
        if (_fromToken == _destToken) {
            return 0;
        }

        //TODO: check if there is enough ETH funds to pay during swap
        uint256 beforeSwappingBalance;
        address dexAddress;
        (beforeSwappingBalance, dexAddress) = _prepareSwap(_fromToken, _destToken, _totalAmountIn, 0x04);

        //TODO: prevent the “sandwich” attack
        uint256 _amountOut = IBalancerExchangeProxy(balancerExchangeProxy).multihopBatchSwapExactIn{value : msg.value}(
            _swapSequences,
            address(_fromToken),
            address(_destToken),
            _totalAmountIn,
            _minTotalAmountOut
        );

        _amountOut = _augmentSwap(_receiver, _destToken, beforeSwappingBalance, _amountOut);

        return _amountOut;
    }

    function _retrieveDexAddress(uint8 _dexFlag) internal override view returns (address){
        if (_dexFlag == _UNISWAPV2) {
            return uniswapV2Router02;
        }
        else if (_dexFlag == _UNISWAPV3) {
            return uniswapV3Router;
        }
        else if (_dexFlag == _SUSHISWAP) {
            return sushiswapV2Router02;
        }
        else if (_dexFlag == _BALANCER) {
            return balancerExchangeProxy;
        }
        else if (_dexFlag == _BANCOR) {
            return IBancorContractRegistry(bancorContractRegistry).addressOf('BancorNetwork');
        }
        else if (_dexFlag == _KYBER) {
            return kyberNetworkProxy;
        }
        return address(0);
    }
}