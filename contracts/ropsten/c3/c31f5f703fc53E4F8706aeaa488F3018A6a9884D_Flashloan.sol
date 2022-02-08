// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Flashloan is FlashLoanReceiverBase {
    using SafeMath for uint256;
    IUniswapV2Router02 sushiswapV1Router;
    ISwapRouter uniswapV3Router;
    uint deadline;
    uint256 amountToTrade;
    uint256 tokensOut;
    address WETH;
    address tokenTransferProxy;
    address paraswap;

    constructor(
        address WethAddress,
        address _addressProvider,
        ISwapRouter _uniswapV3Router,
        address _tokenTransferProxy,
        address _paraswap
        ) FlashLoanReceiverBase(_addressProvider) public {
            WETH = WethAddress;

            // instantiate UniswapV3
            uniswapV3Router = ISwapRouter(address(_uniswapV3Router));

            tokenTransferProxy = _tokenTransferProxy;
            paraswap = _paraswap;

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
        returns (bool)
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        (address flashToken, uint256 flashAmount, uint256 balanceBefore, address arbToken, uint24 fee, uint256 uniswapAmountOutMin, bytes memory _paraswap_calldata) = abi
            .decode(_params, (address, uint256, uint256, address, uint24, uint256, bytes));

        uint256 balanceAfter = IERC20(flashToken).balanceOf(address(this));

        require(
            balanceAfter - balanceBefore == flashAmount,
            "contract did not get the loan"
        );

        //start execute arbitrage
        _arb(flashToken, arbToken, fee, flashAmount, uniswapAmountOutMin, _paraswap_calldata);

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);

    }

    // Get flashloan
    function flashloan(address flashToken, uint256 flashAmount, address arbToken, uint24 fee, uint256 uniswapAmountOutMin) public onlyOwner {
        uint256 balanceBefore = IERC20(flashToken).balanceOf(address(this));
        bytes memory data = abi.encode(flashToken, flashAmount, balanceBefore, arbToken, fee, uniswapAmountOutMin);
        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), flashToken, flashAmount, data);
    }

    function _arb(address _fromToken, address _toToken, uint24 _fee, uint256 _fromAmount, uint256 _uniswapAmountOutMin, bytes memory _paraswap_calldata) internal{
        // Track original balance
        uint256 _startBalance = IERC20(_fromToken).balanceOf(address(this));

        // Perform the arb trade
        _trade(_fromToken, _toToken, _fee, _fromAmount, _uniswapAmountOutMin, _paraswap_calldata);

        // Track result balance
        uint256 _endBalance = IERC20(_fromToken).balanceOf(address(this));

        // Require that arbitrage is profitable
        require(_endBalance > _startBalance, "End balance must exceed start balance.");
    }

    function _trade(address _fromToken, address _toToken, uint24 _fee, uint256 _fromAmount, uint256 _uniswapAmountOutMin, bytes memory _paraswap_calldata) internal{
        // Track the balance of the token RECEIVED from the trade
        uint256 _beforeBalance = IERC20(_toToken).balanceOf(address(this));

        // Swap on uniswap: give _fromToken, receive _toToken
        _uniswapV3RouterSwap(_fromToken, _toToken, _fee, _fromAmount, _uniswapAmountOutMin);

        // Calculate the how much of the token we received
        uint256 _afterBalance = IERC20(_toToken).balanceOf(address(this));

        // Read _toToken balance after swap
        uint256 _toAmount = _afterBalance - _beforeBalance;

        //Swap on sushiswap: give _toToken, receive _fromToken
        swapOnParaswap(_toToken, _toAmount, _paraswap_calldata);
    }

    function uniswapV3RouterSwap(address _from, address _to, uint24 _fee, uint256 _amount, uint256 _amountOutMin) onlyOwner public payable{
        _uniswapV3RouterSwap(_from, _to, _fee, _amount, _amountOutMin);
    }

    function _uniswapV3RouterSwap(address _from, address _to, uint24 _fee, uint256 _amount, uint256 _amountOutMin) internal{
        // Setup contracts
        IERC20 _fromIERC20 = IERC20(_from);

        // Approve tokens
        _fromIERC20.approve(address(uniswapV3Router), _amount);

        // Swap tokens
        ISwapRouter.ExactInputSingleParams memory uniswapV3params = 
        ISwapRouter.ExactInputSingleParams(_from, _to, _fee, address(this), block.timestamp + deadline, _amount, _amountOutMin, 0);

        uniswapV3Router.exactInputSingle(uniswapV3params);

        // Reset approval
        _fromIERC20.approve(address(uniswapV3Router), 0);
    }

    function swapOnParaswap(address _from, uint256 _amount, bytes memory _paraswap_calldata) public{
        _swapOnParaswap(_from, _amount, _paraswap_calldata);
    }

    function _swapOnParaswap(address _from, uint256 _amount, bytes memory _paraswap_calldata) internal{
        // Setup contracts
        IERC20 _fromIERC20 = IERC20(_from);

        // Approve tokens
        _fromIERC20.approve(tokenTransferProxy, _amount);

        // Swap on paraswap
        (bool success, bytes memory returnData) = paraswap.call(_paraswap_calldata);

        require(success, "call to paraswap failed!");

        // Reset approval
        _fromIERC20.approve(tokenTransferProxy, 0);
    }
}