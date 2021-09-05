// "SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.0;

import "./interfaces/IHandler.sol";
import "./libraries/TokenHelper.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniswapV2Handler is IHandler, Ownable {
    using SafeERC20 for IERC20;

    function withdrawn(uint _amount) external override onlyOwner {
        payable(_msgSender()).transfer(_amount); 
        emit Withdrawn(address(0), _msgSender(), _amount);
    }

    function withdrawnToken(address _token, uint _amount) external override onlyOwner {
        IERC20(_token).safeTransfer(_msgSender(), _amount);   
        emit Withdrawn(_token, _msgSender(), _amount);
    }

    /// @dev 根据输入token的数量和兑换路径查询最大输出token数量 
    /// @param _router 交易所地址, router地址
    /// @param _path 兑换路径
    /// @param _amountIn 输入token的数量
    /// @return maximumAmount 最大输出数量
    function quoteOut(address _router, address[] memory _path, uint _amountIn) external override view returns (uint maximumAmount) {
        IUniswapV2Router02 uniswap = IUniswapV2Router02(_router);

        for(uint i = 0; i < _path.length; i++){
            if(_path[i] == address(0)){
                _path[i] = uniswap.WETH();
            }
        }

        try uniswap.getAmountsOut(_amountIn, _path) returns (uint256[] memory v){
            require(v.length >= 2);
            maximumAmount = v[v.length - 1];
        } catch {
            maximumAmount = 0;
        }
    }

    /// @dev 根据输出token的数量和兑换路径查询最小输入token数量
    /// @param _router 交易所地址, router地址
    /// @param _path 兑换路径
    /// @param _amountOut 输出token的数量
    /// @return minimumAmount 最小输入数量
    function quoteIn(address _router, address[] memory _path, uint _amountOut) external override view returns (uint minimumAmount) {
        IUniswapV2Router02 uniswap = IUniswapV2Router02(_router);

        require(_path.length > 1);
        require(_amountOut > 0);
        uniswap = IUniswapV2Router02(_router);

        for(uint i = 0; i < _path.length; i++){
            if(_path[i] == address(0)){
                _path[i] = uniswap.WETH();
            }
        }

        try uniswap.getAmountsIn(_amountOut, _path) returns (uint256[] memory v){
            require(v.length >= 2);
            minimumAmount = v[0];
        } catch {
            minimumAmount = 0;
        }
    }

    /// @dev 具体的swap逻辑在这里处理，不同交易所情况不同
    /// @param _router 交易所地址，uniswapRouter02地址
    /// @param _path 交易路径
    /// @param _time 时间
    function swap(
        address _router,
        address[] memory _path,
        uint24[] memory,
        uint _amountIn,
        address _to,
        uint _minAmountOut,
        uint _time
    ) public payable override returns (uint amount) {
        address tokenIn = _path[0];

        IUniswapV2Router02 uniswap = IUniswapV2Router02(_router);

        if(tokenIn == address(0)){
            amount = swapExactETHForTokens(uniswap, _path, _to, _amountIn, _minAmountOut, _time);
        } else {
            TokenHelper.approveMax(IERC20(tokenIn), address(_router), _amountIn);
            // swap
            amount = swapExactTokensForOthers(uniswap, _path, _to, _amountIn, _minAmountOut, _time);
        }
    }

    /// @dev eth -> tokens
    function swapExactETHForTokens(IUniswapV2Router02 uniswap, address[] memory _path, address _to, uint _amountIn, uint _minAmountOut, uint _time) internal returns (uint amount) {
        _path[0] = uniswap.WETH();
        require(msg.value >= _amountIn, "ETH balance not enough");

        uint256[] memory amounts = uniswap.swapExactETHForTokens{ value: _amountIn }(
            _minAmountOut,
            _path,
            _to,
            block.timestamp + _time
        );
        require(amounts.length >= 2);
        amount = amounts[amounts.length - 1];
    }

    /// @dev tokens -> tokens
    function swapExactTokensForOthers(
        IUniswapV2Router02 uniswap,
        address[] memory _path,
        address _to,
        uint _amountIn,
        uint _minAmountOut,
        uint _time
    ) internal returns (uint amount) {
        if(_path[_path.length - 1] == address(0)) {
            _path[_path.length - 1] = uniswap.WETH();

            uint256[] memory amounts = uniswap.swapExactTokensForETH(
                _amountIn,
                _minAmountOut,
                _path,
                _to,
                block.timestamp + _time
            );
            require(amounts.length >= 2);
            amount = amounts[amounts.length - 1];
        } else { // aave - zero - 1inch
            // zero -> weth
            for(uint i = 0; i < _path.length; i++) {
                if(_path[i] == address(0)) {
                    _path[i] = uniswap.WETH();
                }
            }
            uint256[] memory amounts = uniswap.swapExactTokensForTokens(
                _amountIn,
                _minAmountOut,
                _path,
                _to,
                block.timestamp + _time
            );
            require(amounts.length >= 2);
            amount = amounts[amounts.length - 1];
        }
    }
}