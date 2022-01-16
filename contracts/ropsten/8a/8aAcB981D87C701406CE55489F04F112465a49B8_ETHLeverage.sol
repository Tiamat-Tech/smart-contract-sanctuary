//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
pragma abicoder v2;

import "hardhat/console.sol";

import "../interfaces/IWETH.sol";
import "../interfaces/ICETH.sol";
import "../interfaces/ICERC20.sol";
import "../interfaces/IComptroller.sol";
import "../interfaces/IPriceFeed.sol";

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ETHLeverage is Ownable {
    ISwapRouter public immutable swapRouter;
    uint24 public constant POOL_FEE = 3000;

    ICETH public immutable cETH;
    ICERC20 public immutable cDAI;
    IComptroller public immutable troll;
    IPriceFeed public immutable feed;

    address public immutable DAI;
    address public immutable WETH;

    constructor(
        ISwapRouter _swapRouter,
        address _cETH,
        address _cDAI,
        address _troll,
        address _feed,
        address _DAI,
        address _WETH
    ) {
        swapRouter = _swapRouter;
        cETH = ICETH(_cETH);
        cDAI = ICERC20(_cDAI);
        troll = IComptroller(_troll);
        feed = IPriceFeed(_feed);
        DAI = _DAI;
        WETH = _WETH;
    }

    event Borrow(uint256 collateral, uint256 borrowAmount);
    event RepayBorrow(uint256 repayAmount);
    event Trade(uint256 amountIn, uint256 amountOut);
    event Deposit(uint256 amountIn);
    event Withdraw(uint256 amountOut);

    function deposit() external payable onlyOwner {
        // Get ETH price
        uint256 price = feed.getUnderlyingPrice(address(cETH));
        console.log("ETH Price: ", price / 1e18, "USD");

        // Borrow
        uint256 amount = (((msg.value) / 2) * price) / 1e18;
        console.log("Deposit Amount: ", msg.value);
        uint256 borrows = borrow(msg.value, amount);

        // Trade DAI for WETH
        uint256 amountOut = tradeExactInput(DAI, WETH, borrows);
        console.log("Trade %s DAI for %s WETH", borrows / 1e18, amountOut / 1e18);

        console.log(
            "%s DAI, %s WETH, %s ETH left in contract",
            IERC20(DAI).balanceOf(address(this)),
            IWETH(WETH).balanceOf(address(this)),
            address(this).balance
        );

        emit Deposit(msg.value);
    }

    function withdraw() external onlyOwner {
        // Trade WETH for DAI
        uint256 currentWETHBalance = IWETH(WETH).balanceOf(address(this));
        uint256 amountOutDAI = tradeExactInput(WETH, DAI, currentWETHBalance);
        console.log("Trade %s WETH for %s DAI", currentWETHBalance / 1e18, amountOutDAI / 1e18);

        // Repay Borrow
        uint256 currentBorrowBalance = cDAI.borrowBalanceCurrent(address(this));
        uint256 currentDAIBalance = IERC20(DAI).balanceOf(address(this));
        require(currentDAIBalance >= currentBorrowBalance, "Please add DAI to this contract");
        repayBorrow(currentBorrowBalance);

        // Trade Remaining DAI back to WETH
        currentDAIBalance = IERC20(DAI).balanceOf(address(this));
        console.log("DAI Left After Repay: ", currentDAIBalance / 1e18, "DAI");
        if (currentDAIBalance > 0) {
            uint256 amountOutWETH = tradeExactInput(DAI, WETH, currentDAIBalance);
            console.log("Trade %s DAI for %s wei", currentDAIBalance / 1e18, amountOutWETH);
        }

        // Unwrap WETH to ETH
        IWETH(WETH).withdraw(IWETH(WETH).balanceOf(address(this)));

        // Transfer to Owner
        uint256 withdrawAmount = address(this).balance;
        console.log("Withdraw Amount: ", withdrawAmount);
        TransferHelper.safeTransferETH(msg.sender, withdrawAmount);

        console.log(
            "%s DAI, %s WETH, %s ETH left in contract",
            IERC20(DAI).balanceOf(address(this)),
            IWETH(WETH).balanceOf(address(this)),
            address(this).balance
        );

        emit Withdraw(withdrawAmount);
    }

    function tradeExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) internal returns (uint256 amountOut) {
        // Approve UNISWAP to use our token
        TransferHelper.safeApprove(_tokenIn, address(swapRouter), _amountIn);

        // Prepare struct for swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Swap
        amountOut = swapRouter.exactInputSingle(params);

        emit Trade(_amountIn, amountOut);
    }

    function borrow(uint256 _collateralAmount, uint256 _amount) internal returns (uint256 borrows) {
        // Supply Collateral
        cETH.mint{value: _collateralAmount}();

        // Enter Market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cETH);
        uint256[] memory errors = troll.enterMarkets(cTokens);
        require(errors[0] == 0, "Enter Market Failed");

        // Get Account Liquidity
        (uint256 _error, uint256 liquidity, uint256 shortfall) = troll.getAccountLiquidity(address(this));
        require(_error == 0, "Get account liquidity failed");
        require(shortfall == 0, "Subject to liquidation");
        require(liquidity > 0, "Account has no liquidity");

        // Logging Borrow Information
        (bool isListed, uint256 collateralFactorMantissa) = troll.markets(address(cETH));
        require(isListed == true, "ETH is not listed");
        console.log("Allow to borrow: ", liquidity / 1e18, "USD");
        console.log("ETH Collateral Factor: ", collateralFactorMantissa / 1e16, "%");

        // Borrow
        cDAI.borrow(_amount);
        console.log("Borrow Amount: ", _amount / 1e18, "DAI");

        // Logging Current Borrow Balance
        borrows = cDAI.borrowBalanceCurrent(address(this));
        console.log("Current DAI Borrow Amount: ", borrows / 1e18, "DAI");

        // Loggin Borrow Rate
        uint256 borrowRateMantissa = cDAI.borrowRatePerBlock();
        console.log("DAI Borrow Rate: ", borrowRateMantissa);

        emit Borrow(collateralFactorMantissa, borrows);
    }

    function repayBorrow(uint256 _amount) internal {
        // Repay Borrow
        TransferHelper.safeApprove(DAI, address(cDAI), _amount);
        uint256 repayError = cDAI.repayBorrow(_amount);
        require(repayError == 0, "Repay Error");
        console.log("Repay Amount: ", _amount);

        // Logging Current Borrow Balance
        uint256 borrows = cDAI.borrowBalanceCurrent(address(this));
        console.log("Current DAI Borrow Amount: ", borrows / 1e18, "DAI");

        // Redeem Collateral
        uint256 cETHBalance = cETH.balanceOf(address(this));
        uint256 redeemError = cETH.redeem(cETHBalance);
        require(redeemError == 0, "Redeem Error");
        console.log("Collateral Returned: ", address(this).balance / 1e18, "ETH");

        emit RepayBorrow(_amount);
    }

    receive() external payable {}
}