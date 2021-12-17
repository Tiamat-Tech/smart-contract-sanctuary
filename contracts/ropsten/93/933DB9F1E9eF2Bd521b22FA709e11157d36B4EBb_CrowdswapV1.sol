// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

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
import "./test/lib/path.sol";
import "./test/lib/BytesLib.sol";

contract CrowdswapV1 is Crowdswap {

    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    using Path for bytes;
    using BytesLib for bytes;

    constructor(
        address _uniswap2,
        address _uniswap3,
        address _sushiswap,
        address _balancer,
        address _bancor,
        address _kyber
    ){
        dexchanges[_UNISWAPV2] = _uniswap2;
        dexchanges[_UNISWAPV3] = _uniswap3;
        dexchanges[_SUSHISWAP] = _sushiswap;
        dexchanges[_BALANCER] = _balancer;
        dexchanges[_BANCOR] = _bancor;
        dexchanges[_KYBER] = _kyber;
    }

    function setUniswapV2Router02(address _uniswapAddress) external onlyOwner {
        require(_uniswapAddress != address(0), "ce02");
        dexchanges[_UNISWAPV2] = _uniswapAddress;
    }

    function setUniswapV3Router(address _uniswapAddress) external onlyOwner {
        require(_uniswapAddress != address(0), "ce02");
        dexchanges[_UNISWAPV3] = _uniswapAddress;
    }

    function setSushiswapV2Router02(address _sushiAddress) external onlyOwner {
        require(_sushiAddress != address(0), "ce02");
        dexchanges[_SUSHISWAP] = _sushiAddress;
    }

    function setBalancerExchangeProxy(address _balancer) external onlyOwner {
        require(_balancer != address(0), "ce02");
        dexchanges[_BALANCER] = _balancer;
    }

    function setBancorContractRegistry(address _bancor) external onlyOwner {
        require(_bancor != address(0), "ce02");
        dexchanges[_BANCOR] = _bancor;
    }

    function setKyberNetworkProxy(address _kyber) external onlyOwner {
        require(_kyber != address(0), "ce02");
        dexchanges[_KYBER] = _kyber;
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

        (uint256 beforeSwappingBalance, address dexAddress) = super._prepareSwap(_fromToken, _destToken, _desc.amountIn, _dexFlag);

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
        amountOut = super._augmentSwap(_receiver, _destToken, beforeSwappingBalance, amountOut);

        return amountOut;
    }

    function swap(
        IERC20 _fromToken,
        IERC20 _destToken,
        address payable _receiver,
        uint256 _amountIn,
        uint8 _dexFlag,
        bytes calldata _data
    )
    external payable returns (uint256 returnAmount){
        if (_fromToken == _destToken) {
            return 0;
        }
        
        (uint256 beforeSwappingBalance, address dexAddress) = super._prepareSwap(_fromToken, _destToken, _amountIn, _dexFlag);

        Address.functionCallWithValue(dexAddress, _data, msg.value);

        uint256 amountOut = super._augmentSwap(_receiver, _destToken, beforeSwappingBalance);

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

        (uint256 beforeSwappingBalance, address dexAddress) = super._prepareSwap(_fromToken, _destToken, _totalAmountIn, 0x04);

        uint256 amountOut = IBalancerExchangeProxy(dexAddress).multihopBatchSwapExactIn{value : msg.value}(
            _swapSequences,
            address(_fromToken),
            address(_destToken),
            _totalAmountIn,
            _minTotalAmountOut
        );

        amountOut = super._augmentSwap(_receiver, _destToken, beforeSwappingBalance, amountOut);

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

        (uint256 _beforeSwappingBalance,address _dexAddress) = super._prepareSwap(_fromToken, _destToken, _amountIn, 0x02);

        IUniswapV3Router.ExactInputParams memory uni3Params = IUniswapV3Router.ExactInputParams(
            _path,
            address(this),
            _deadline,
            _amountIn,
            _amountOutMin
        );
        uint256 amountOut = IUniswapV3Router(_dexAddress).exactInput{value : msg.value}(
            uni3Params
        );
        amountOut = super._augmentSwap(_receiver, _destToken, _beforeSwappingBalance, amountOut);

        return amountOut;
    }

    function _retrieveDexAddress(uint8 _dexFlag) internal override view returns (address){
        address _dexchange = dexchanges[_dexFlag];
        if(_dexFlag == _BANCOR){
            return IBancorContractRegistry(_dexchange).addressOf('BancorNetwork');
        }
        return _dexchange;
    }
}