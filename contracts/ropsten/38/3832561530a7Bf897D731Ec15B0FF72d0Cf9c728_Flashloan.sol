pragma solidity ^0.6.6;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Flashloan is FlashLoanReceiverBase {
    using SafeMath for uint256;
    IUniswapV2Router02 uniswapV2Router;
    IUniswapV2Router02 sushiswapV1Router;
    uint deadline;
    uint256 amountToTrade;
    uint256 tokensOut;
    address WETH;

    constructor(
        address WethAddress,
        address _addressProvider,
        IUniswapV2Router02 _uniswapV2Router,
        IUniswapV2Router02 _sushiswapV1Router
        ) FlashLoanReceiverBase(_addressProvider) public {
            WETH = WethAddress;

            // instantiate UniswapV2 Router02 and Sushiswap Router02
            uniswapV2Router = IUniswapV2Router02(address(_uniswapV2Router));
            sushiswapV1Router = IUniswapV2Router02(address(_sushiswapV1Router));

            // setting deadline to avoid scenario where miners hang onto it and execute at a more profitable time
            deadline = 300; // 5 minutes
        }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        (address flashToken, uint256 flashAmount, uint256 balanceBefore, address arbToken, uint256 uniswapAmountOutMin) = abi
            .decode(_params, (address, uint256, uint256, address, uint256));

        uint256 balanceAfter = IERC20(flashToken).balanceOf(address(this));

        require(
            balanceAfter - balanceBefore == flashAmount,
            "contract did not get the loan"
        );

        //start execute arbitrage
        _arb(flashToken, arbToken, flashAmount, uniswapAmountOutMin);

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    // Get flashloan
    function flashloan(address flashToken, uint256 flashAmount, address arbToken, uint256 uniswapAmountOutMin) public onlyOwner {
        uint256 balanceBefore = IERC20(flashToken).balanceOf(address(this));
        bytes memory data = abi.encode(flashToken, flashAmount, balanceBefore, arbToken, uniswapAmountOutMin);
        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), flashToken, flashAmount, data);
    }

    function _arb(address _fromToken, address _toToken, uint256 _fromAmount, uint256 _uniswapAmountOutMin) internal{
        // Track original balance
        uint256 _startBalance = IERC20(_fromToken).balanceOf(address(this));

        // Perform the arb trade
        _trade(_fromToken, _toToken, _fromAmount, _uniswapAmountOutMin);

        // Track result balance
        uint256 _endBalance = IERC20(_fromToken).balanceOf(address(this));

        // Require that arbitrage is profitable
        require(_endBalance > _startBalance, "End balance must exceed start balance.");
    }

    function _trade(address _fromToken, address _toToken, uint256 _fromAmount, uint256 _uniswapAmountOutMin) internal{
        // Track the balance of the token RECEIVED from the trade
        uint256 _beforeBalance = IERC20(_toToken).balanceOf(address(this));

        // Swap on uniswap: give _fromToken, receive _toToken
        _uniswapV2RouterSwap(_fromToken, _toToken, _fromAmount, _uniswapAmountOutMin);

        // Calculate the how much of the token we received
        uint256 _afterBalance = IERC20(_toToken).balanceOf(address(this));

        // Read _toToken balance after swap
        uint256 _toAmount = _afterBalance - _beforeBalance;

        // Get sushiswap amountsOut
        uint256 estimatedAmount = getEstimatedAmount(_toToken, _fromToken, _toAmount);

        //Swap on sushiswap: give _toToken, receive _fromToken
        _sushiswapV1RouterSwap(_toToken, _fromToken, _toAmount, estimatedAmount);
    }

    function uniswapV2RouterSwap(address _from, address _to, uint256 _amount, uint256 _amountOutMin) onlyOwner public payable{
        _uniswapV2RouterSwap(_from, _to, _amount, _amountOutMin);
    }

    function _uniswapV2RouterSwap(address _from, address _to, uint256 _amount, uint256 _amountOutMin) internal{
        // Setup contracts
        IERC20 _fromIERC20 = IERC20(_from);

        // Approve tokens
        _fromIERC20.approve(address(uniswapV2Router), _amount);

        // Swap tokens
        uniswapV2Router.swapExactTokensForTokens(_amount, _amountOutMin, getSwapPath(_from, _to), address(this), block.timestamp + deadline);

        // Reset approval
        _fromIERC20.approve(address(uniswapV2Router), 0);
    }

    function sushiswapV1RouterSwap(address _from, address _to, uint256 _amount, uint256 _amountOutMin) onlyOwner public payable{
        _sushiswapV1RouterSwap(_from, _to, _amount, _amountOutMin);
    }

    function _sushiswapV1RouterSwap(address _from, address _to, uint256 _amount, uint256 _amountOutMin) internal{
        // Setup contracts
        IERC20 _fromIERC20 = IERC20(_from);

        // Approve tokens
        _fromIERC20.approve(address(sushiswapV1Router), _amount);

        // Swap tokens
        sushiswapV1Router.swapExactTokensForTokens(_amount, _amountOutMin, getSwapPath(_from, _to), address(this), block.timestamp + deadline);

        // Reset approval
        _fromIERC20.approve(address(sushiswapV1Router), 0);
    }

    function getSwapPath(address _from, address _to) internal view returns (address[] memory){
        //Set path
        address[] memory path;
        if (_from == WETH || _to == WETH){
            path = new address[](2);
            path[0] = _from;
            path[1] = _to;
        }else{
            path = new address[](3);
            path[0] = _from;
            path[1] = WETH;
            path[2] = _to;
        }

        return path;
    }

    function getEstimatedAmount(address _from, address _to, uint256 _amount) internal view returns(uint256){
        return sushiswapV1Router.getAmountsOut(_amount, getSwapPath(_from, _to))[0];
    }
}