// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "./interface/ICrowdswap.sol";
import "./interface/IUniswapV2Router02.sol";
import "./interface/IBancorNetwork.sol";
import "./interface/IBalancerExchangeProxy.sol";
import "./interface/IBalancerExchangeProxy.sol";
import "./interface/IKyberNetworkProxy.sol";
import "./helpers/UniERC20.sol";
import "./helpers/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdswapV1 is Ownable, ICrowdswap {

    using UniERC20 for IERC20;
    using SafeERC20 for IERC20;

    int256 percentage = 10**17;//0.1

    address private uniswapV2Router02;
    address private sushiswapV2Router02;
    address private bancorContractRegistry;
    address private balancerExchangeProxy;
    address private kyberNetworkProxy;

    uint8 private constant _UNISWAPV2 = 0x01;
    uint8 private constant _UNISWAPV3 = 0x02;
    uint8 private constant _SUSHISWAP = 0x03;
    uint8 private constant _BALANCER = 0x04;
    uint8 private constant _BANCOR = 0x05;
    uint8 private constant _KYBER = 0x06;

    event SwapSucceedEvent(IERC20 _destToken, uint256 amountOut, uint256 fee);
    event WithdrawTokenSucceedEvent(IERC20 token, address receiver, uint256 amount);
    event WithdrawBaseTokenSucceedEvent(address receiver, uint256 amount);

    constructor(
        address _uniswap,
        address _sushiswap,
        address _balancer,
        address _bancor,
        address _kyber
    ){
        uniswapV2Router02 = _uniswap;
        sushiswapV2Router02 = _sushiswap;
        balancerExchangeProxy = _balancer;
        bancorContractRegistry = _bancor;
        kyberNetworkProxy = _kyber;
    }

    receive() external payable {}

    fallback() external {
        revert("ce01");
    }

    function setUniswapV2Router02(address uniswapAddress) external onlyOwner {
        require(uniswapAddress != address(0), "ce02");
        uniswapV2Router02 = uniswapAddress;
    }

    function getUniswapV2Router02() public view returns(address){
        return uniswapV2Router02;
    }

    function setSushiswapV2Router02(address sushiAddress) external onlyOwner {
        require(sushiAddress != address(0), "ce02");
        sushiswapV2Router02 = sushiAddress;
    }

    function getSushiswapV2Router02() public view returns(address){
        return sushiswapV2Router02;
    }

    function setBalancerExchangeProxy(address _balancer) external onlyOwner {
        require(_balancer != address(0), "ce02");
        balancerExchangeProxy = _balancer;
    }

    function getBalancerExchangeProxy() public view returns(address){
        return balancerExchangeProxy;
    }

    function setBancorContractRegistry(address _bancor) external onlyOwner {
        require(_bancor != address(0), "ce02");
        bancorContractRegistry = _bancor;
    }

    function getBancorContractRegistry() public view returns(address){
        return bancorContractRegistry;
    }

    function setKyberNetworkProxy(address _kyber) external onlyOwner {
        require(_kyber != address(0), "ce02");
        kyberNetworkProxy = _kyber;
    }

    function getKyberNetworkProxy() public view returns(address){
        return kyberNetworkProxy;
    }
    
    function setPercentage(int256 _percentage) external onlyOwner {
        require(_percentage >= 0, "ce05");
        percentage = _percentage;
    }

    function getPercentage() external view returns (int256){
        return percentage;
    }

    function getBalance() external view returns (uint256){
        return address(this).balance;
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
        (uint256 _beforeSwappingBalance,address _dexAddress) = _prepareSwap(_fromToken, _destToken, _desc.amountIn, _dexFlag);

        //TODO: prevent the “sandwich” attack
        uint256[] memory dexResult;
        if (_dexFlag == _UNISWAPV2 || _dexFlag == _SUSHISWAP) {
            if (_fromToken.isETH()) {
                dexResult = IUniswapV2Router02(_dexAddress).swapExactETHForTokens{value : msg.value}(
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline
                );
            } else if (_destToken.isETH()) {
                dexResult = IUniswapV2Router02(_dexAddress).swapExactTokensForETH(
                    _desc.amountIn,
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline);
            } else {
                dexResult = IUniswapV2Router02(_dexAddress).swapExactTokensForTokens(
                    _desc.amountIn,
                    _desc.amountOutMin,
                    _desc.path,
                    address(this),
                    _desc.deadline);
            }
        }
        else if (_dexFlag == _BALANCER) {
            revert("ce99");
        }
        else if (_dexFlag == _BANCOR) {
            dexResult = new uint256[](1);
            dexResult[0] = IBancorNetwork(_dexAddress).convertByPath{value : msg.value}(
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
            dexResult[0] = IKyberNetworkProxy(_dexAddress).tradeWithHintAndFee{value : msg.value}(
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
    external override payable returns (uint256){
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

    function withdrawAllToken(address _token) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        withdrawToken(_token, balance);
    }

    function withdrawAllBaseToken() external onlyOwner {
        withdrawBaseToken(address(this).balance);
    }

    function withdrawToken(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
        emit WithdrawTokenSucceedEvent(IERC20(_token), owner(), _amount);
    }

    function withdrawBaseToken(uint256 _amount) public onlyOwner {
        payable(owner()).transfer(_amount);
        emit WithdrawBaseTokenSucceedEvent(owner(), _amount);
    }

    function _retrieveDexAddress(uint8 _dexFlag) private view returns (address){
        if (_dexFlag == _UNISWAPV2) {
            return uniswapV2Router02;
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

    function _feeCalculator(
        uint256 _withdrawalAmount,
        int256 _percentage
    ) private pure returns (uint256){
        uint256 fee = uint256(_percentage) * _withdrawalAmount/ (10 ** 18)  / 100;
    return fee;
    }

    function _prepareSwap(
        IERC20 _fromToken,
        IERC20 _destToken,
        uint256 _amountIn,
        uint8 _dexFlag
    ) private returns (uint256, address){
        require(msg.value == (_fromToken.isETH() ? _amountIn : 0), "ce06");

        uint256 _beforeSwappingBalance = _destToken.uniBalanceOf(address(this));

        address _dexAddress = _retrieveDexAddress(_dexFlag);
        require(_dexAddress != address(0), "ce07");
        if (!_fromToken.isETH()) {
            _fromToken.safeTransferFrom(msg.sender, address(this), _amountIn);
            _fromToken.uniApprove(_dexAddress, _amountIn);
        }

        return (_beforeSwappingBalance, _dexAddress);
    }

    function _augmentSwap(
        address _receiver,
        IERC20 _destToken,
        uint256 _beforeSwappingBalance,
        uint256 _amountOut
    ) private returns (uint256){
        uint256 _afterSwappingBalance = _destToken.uniBalanceOf(address(this));
        require(_afterSwappingBalance - _beforeSwappingBalance == _amountOut, "ce08");

        uint256 _fee = _feeCalculator(_amountOut, percentage);
        _amountOut = _amountOut - _fee;
        _destToken.uniTransfer(payable(_receiver), _amountOut);

        emit SwapSucceedEvent(_destToken, _amountOut, _fee);

        return _amountOut;
    }
}