// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IUniswapV2Router.sol";

contract TradingContract is Ownable {
    using SafeERC20 for IERC20;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant WETH = 0x0a180A76e4466bF68A7F86fB029BEd3cCcFaAac5;

    mapping(address => bool) public whitelists;

    event DepositETH(uint amount);
    event WithdrawETH(uint amount);

    event DepositToken(address indexed addr, uint amount);
    event WithdrawToken(address indexed addr, uint amount);

    constructor(address[] memory _whitelists) {
        for (uint i = 0; i < _whitelists.length; i ++) {
            whitelists[_whitelists[i]] = true;
        }
    }

    function getBalance() public view returns(uint){
        return address(this).balance;
    }

    modifier checkWhiteList() {
        require(whitelists[msg.sender] == true, "Not whitelist address");
        _;
    }

    function addWhitelist(address whiteAddress) external onlyOwner {
        whitelists[whiteAddress] = true;
    }

    function removeWhitelist(address whiteAddress) external onlyOwner {
        whitelists[whiteAddress] = false;
    }

    function depositETH() external payable {
        emit DepositETH(msg.value);
    }

    function withdrawETH(uint ethAmount) external checkWhiteList {
        require(address(this).balance >= ethAmount, "Insufficient ETH");
        (bool sent,) = payable(msg.sender).call{value: ethAmount}("");
        require(sent, "Failed to send Ether");
        emit WithdrawETH(ethAmount);
    }

    function depositToken(address tokenAddress, uint amount) external {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        emit DepositToken(msg.sender, amount);
    }

    function withdrawToken(address tokenAddress, uint amount) external checkWhiteList {
        require(IERC20(tokenAddress).balanceOf(address(this)) >= amount, "Insufficient balance");
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
        emit WithdrawToken(msg.sender, amount);
    }

    function swapToken(address _tokenIn, address _tokenOut, uint _amountIn, address _to) external checkWhiteList returns(uint) {
        require(IERC20(_tokenIn).balanceOf(address(this)) >= _amountIn, "Insufficient token balance");
        IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }
        uint[] memory reserveAmounts = IUniswapV2Router(UNISWAP_V2_ROUTER).getAmountsOut(
            _amountIn,
            path
        );
        uint[] memory realAmounts = IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            _amountIn,
            reserveAmounts[reserveAmounts.length - 1]*100/50,
            path,
            _to,
            block.timestamp
        );
        return realAmounts[realAmounts.length - 1];
    }
}