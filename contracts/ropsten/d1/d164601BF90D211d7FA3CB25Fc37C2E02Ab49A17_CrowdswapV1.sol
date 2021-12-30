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

contract CrowdswapV1 is Crowdswap {

    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    constructor(
        DexAddress[] memory dexAddresses
    ){
        for(uint i = 0; i < dexAddresses.length; i++){
            DexAddress memory dexAddress = dexAddresses[i];
            if(dexAddress.adr != address(0)){
                dexchanges[dexAddress.flag] = dexAddress.adr;        
            }
        }
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

    function _retrieveDexAddress(uint8 _dexFlag) internal override view returns (address){
        address _dexchange = dexchanges[_dexFlag];
        if(_dexFlag == _BANCOR){
            return IBancorContractRegistry(_dexchange).addressOf('BancorNetwork');
        }
        return _dexchange;
    }
}