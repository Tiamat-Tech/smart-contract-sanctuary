// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IUniswapV2Router01.sol";

contract SimpleIndex is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // MAINET
    // address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address private constant ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address private constant BTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    // ROPSTEN
    address private constant USDC = 0xFE724a829fdF12F7012365dB98730EEe33742ea2;
    address private constant ETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address private constant BTC = 0x65058d7081FCdC3cd8727dbb7F8F9D52CefDd291;

    mapping (address => uint256) private ETH_balances;
    mapping (address => uint256) private BTC_balances;

    function want() public pure returns (IERC20) {
        return IERC20(USDC);
    }

    function deposit(uint256 _amount) public nonReentrant whenNotPaused {
        want().safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _amount1 = _amount.div(2);
        uint256 _amount2 = _amount.sub(_amount1);

        addETH(_amount1);
        addBTC(_amount2);
    }

    function addETH(uint256 _amount) internal {
        uint256 _before = IERC20(ETH).balanceOf(address(this));

        uint256 _amountMin = getAmountOutMin(USDC, ETH, _amount);
        swap(USDC, ETH, _amount, _amountMin);

        uint256 _after = IERC20(ETH).balanceOf(address(this));

        ETH_balances[msg.sender] = ETH_balances[msg.sender].add(_after.sub(_before));
    }

    function addBTC(uint256 _amount) internal {
        uint256 _before = IERC20(BTC).balanceOf(address(this));

        uint256 _amountMin = getAmountOutMin(USDC, BTC, _amount);
        swap(USDC, BTC, _amount, _amountMin);

        uint256 _after = IERC20(BTC).balanceOf(address(this));

        BTC_balances[msg.sender] = BTC_balances[msg.sender].add(_after.sub(_before));
    }

    function balanceOf(address _address) view public returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](2);

        balances[0] = ETH_balances[_address];
        balances[1] = BTC_balances[_address];

        return balances;
    }

    function depositAll() external {
        deposit(want().balanceOf(msg.sender));
    }

    function withdrawETH(uint256 _amount) internal returns (uint256) {
        uint256 _amountMin = getAmountOutMin(ETH, USDC, _amount);
        swap(ETH, USDC, _amount, _amountMin);

        return _amountMin;
    }

    function withdrawBTC(uint256 _amount) internal returns (uint256) {
        uint256 _amountMin = getAmountOutMin(BTC, USDC, _amount);
        swap(BTC, USDC, _amount, _amountMin);

        return _amountMin;
    }

    function withdrawAll() external {
        uint256 amount1 = withdrawETH(ETH_balances[msg.sender]);
        uint256 amount2 = withdrawBTC(BTC_balances[msg.sender]);

        want().safeTransfer(msg.sender, amount1.add(amount2));
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getAmountOutMin(address _tokenIn, address _tokenOut, uint256 _amountIn) internal view returns (uint256) {

        address[] memory path;
        if (_tokenIn == ETH || _tokenOut == ETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = ETH;
            path[2] = _tokenOut;
        }

        uint256[] memory amountOutMins = IUniswapV2Router01(UNISWAP_V2_ROUTER).getAmountsOut(_amountIn, path);
        return amountOutMins[path.length -1];
    }

    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMin) internal {

        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == ETH || _tokenOut == ETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = ETH;
            path[2] = _tokenOut;
        }

        IUniswapV2Router01(UNISWAP_V2_ROUTER).swapExactTokensForTokens(_amountIn, _amountOutMin, path, address(this), block.timestamp);
    }
}