// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//import "hardhat/console.sol";

contract UniswapV3Router is ReentrancyGuard, Ownable {
    event CommissionPaid(uint256 _amount, uint256 _when, address _who, address _where, address _what);

    ISwapRouter public immutable swapRouter;
    address internal commissionAddress;
    address internal wrappedEthereum = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;

    struct Swap {
        uint256 amountToBuy;
        uint256 amountToSell;
        address tokenToBuy;
        uint256 deadline;
        // The pools in which the trade will route
        Pool[] pools;
        // If selling, the total sell amount must not exceed amountToSell
        // For buy it must not be below amountToBuy
        Side fixedSide;
        Commission commission;
    }

    struct Pool {
        address token;
        uint24 poolFee;
    }

    struct Commission {
        uint256 commissionPercentage;
        Side side;
    }

    enum Side {
        Buy,
        Sell
    }

    constructor(ISwapRouter _swapRouter, address _commissionAddress) {
        swapRouter = ISwapRouter(_swapRouter);
        commissionAddress = _commissionAddress;
    }

    function changeCommissionAddress(address _address) public onlyOwner {
        commissionAddress = _address;
    }

    function changeWrappedEthereumAddress(address _address) public onlyOwner {
        wrappedEthereum = _address;
    }

    function doSwap(Swap memory _swap) external nonReentrant returns (uint256) {
        // take the funds from the user
        TransferHelper.safeTransferFrom(_swap.pools[0].token, msg.sender, address(this), _swap.amountToSell);

        // If we are taking the commission from the token being sold
        // take the commission before the swap
        if (_swap.commission.side == Side.Sell) {
            uint256 commissionPaid = payTokenCommission(_swap);
            _swap.amountToSell = _swap.amountToSell - commissionPaid;

            // If the fixed side is buy, reduce the amount we are buying by the same % as we've taken from the sell side
            if (_swap.fixedSide == Side.Buy) {
                uint256 commission = calculateCommission(_swap.amountToBuy, _swap.commission.commissionPercentage);
                _swap.amountToBuy = _swap.amountToBuy - commission;
            }
        }

        // Approve the router to spend the token we are selling
        TransferHelper.safeApprove(_swap.pools[0].token, address(swapRouter), _swap.amountToSell);

        uint256 result;
        if (_swap.fixedSide == Side.Buy) {
            result = swapWithExactOutput(_swap, false);
        } else {
            result = swapWithExactInput(_swap, false);
        }

        TransferHelper.safeApprove(_swap.pools[0].token, address(swapRouter), 0);

        // Take buy side commission
        if (_swap.commission.side == Side.Buy) {
            payTokenCommission(_swap);
        }

        IERC20 tokenBought = IERC20(_swap.tokenToBuy);

        // transfer all remaining purchased tokens to the user
        tokenBought.transfer(msg.sender, tokenBought.balanceOf(address(this)));

        return result;
    }

    function doEthSwap(Swap memory _swap) external payable nonReentrant returns (uint256) {
        _swap.pools[0].token = wrappedEthereum;
        _swap.amountToSell = msg.value;

        // If we are taking the commission from the token being sold
        // take the commission before the swap
        if (_swap.commission.side == Side.Sell) {
            uint256 commissionPaid = payEthCommission(_swap);
            _swap.amountToSell = _swap.amountToSell - commissionPaid;

            // If the fixed side is buy, reduce the amount we are buying by the same % as we've taken from the sell side
            if (_swap.fixedSide == Side.Buy) {
                uint256 commission = calculateCommission(_swap.amountToBuy, _swap.commission.commissionPercentage);
                _swap.amountToBuy = _swap.amountToBuy - commission;
            }
        }

        uint256 result;
        if (_swap.fixedSide == Side.Buy) {
            result = swapWithExactOutput(_swap, true);
        } else {
            result = swapWithExactInput(_swap, true);
        }

        if (_swap.commission.side == Side.Buy) {
            payTokenCommission(_swap);
        }

        return result;
    }

    function swapWithExactInput(Swap memory _swap, bool _isEthTrade) internal returns (uint256 _amountSold) {
        // multi pool swap
        if (_swap.pools.length > 1) {
            return swapWithExactInputMultiPool(_swap, _isEthTrade);
        } else {
            return swapWithExactInputSinglePool(_swap, _isEthTrade);
        }
    }

    function swapWithExactOutput(Swap memory _swap, bool _isEthTrade) internal returns (uint256 _amountBought) {
        // multi pool swap
        if (_swap.pools.length > 1) {
            return swapWithExactOutputMultiPool(_swap, _isEthTrade);
        } else {
            return swapWithExactOutputSinglePool(_swap, _isEthTrade);
        }
    }

    function swapWithExactInputSinglePool(Swap memory _swap, bool _isEthTrade)
    internal
    returns (uint256 _amountBought)
    {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        tokenIn : _swap.pools[0].token,
        fee : _swap.pools[0].poolFee,
        tokenOut : _swap.tokenToBuy,
        recipient : address(this),
        deadline : _swap.deadline,
        amountIn : _swap.amountToSell,
        amountOutMinimum : _swap.amountToBuy,
        sqrtPriceLimitX96 : 0
        });

        if (_isEthTrade) {
            return swapRouter.exactInputSingle{value : _swap.amountToSell}(params);
        } else {
            return swapRouter.exactInputSingle(params);
        }
    }

    function swapWithExactOutputSinglePool(Swap memory _swap, bool _isEthTrade)
    internal
    returns (uint256 _amountBought)
    {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
        tokenIn : _swap.pools[0].token,
        fee : _swap.pools[0].poolFee,
        tokenOut : _swap.tokenToBuy,
        recipient : address(this),
        deadline : _swap.deadline,
        amountInMaximum : _swap.amountToSell,
        amountOut : _swap.amountToBuy,
        sqrtPriceLimitX96 : 0
        });

        if (_isEthTrade) {
            return swapRouter.exactOutputSingle{value : _swap.amountToSell}(params);
        } else {
            return swapRouter.exactOutputSingle(params);
        }
    }

    function swapWithExactInputMultiPool(Swap memory _swap, bool _isEthTrade) internal returns (uint256 _amountBought) {
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
        path : abi.encodePacked(
                _swap.pools[0].token,
                _swap.pools[0].poolFee,
                _swap.pools[1].token,
                _swap.pools[1].poolFee,
                _swap.tokenToBuy
            ),
        recipient : address(this),
        deadline : _swap.deadline,
        amountIn : _swap.amountToSell,
        amountOutMinimum : _swap.amountToBuy
        });

        if (_isEthTrade) {
            return swapRouter.exactInput{value : _swap.amountToSell}(params);
        } else {
            return swapRouter.exactInput(params);
        }
    }

    function swapWithExactOutputMultiPool(Swap memory _swap, bool _isEthTrade)
    internal
    returns (uint256 _amountBought)
    {
        ISwapRouter.ExactOutputParams memory params = ISwapRouter.ExactOutputParams({
        path : abi.encodePacked(
                _swap.pools[0].token,
                _swap.pools[0].poolFee,
                _swap.pools[1].token,
                _swap.pools[1].poolFee,
                _swap.tokenToBuy
            ),
        recipient : address(this),
        deadline : _swap.deadline,
        amountInMaximum : _swap.amountToSell,
        amountOut : _swap.amountToBuy
        });

        if (_isEthTrade) {
            return swapRouter.exactOutput{value : _swap.amountToSell}(params);
        } else {
            return swapRouter.exactOutput(params);
        }
    }

    function payTokenCommission(Swap memory _swap) internal returns (uint256 _commissionPaid) {
        uint256 commission;

        if (_swap.commission.side == Side.Buy) {
            commission = calculateCommission(_swap.amountToBuy, _swap.commission.commissionPercentage);
            TransferHelper.safeTransfer(_swap.tokenToBuy, commissionAddress, commission);

            emit CommissionPaid(commission, block.timestamp, msg.sender, commissionAddress, _swap.tokenToBuy);
        } else {
            commission = calculateCommission(_swap.amountToSell, _swap.commission.commissionPercentage);
            TransferHelper.safeTransfer(_swap.pools[0].token, commissionAddress, commission);

            emit CommissionPaid(commission, block.timestamp, msg.sender, commissionAddress, _swap.pools[0].token);
        }

        return commission;
    }

    function payEthCommission(Swap memory _swap) internal returns (uint256 _commissionPaid) {
        uint256 commission = calculateCommission(msg.value, _swap.commission.commissionPercentage);

        (bool success,) = commissionAddress.call{value : commission}("");

        if (!success) {
            revert("Error paying out commission");
        }

        emit CommissionPaid(commission, block.timestamp, msg.sender, commissionAddress, address(0));

        return commission;
    }

    function calculateCommission(uint256 _amount, uint256 _percentage) public pure returns (uint256) {
        return (_amount / 100) * _percentage;
    }

    receive() external payable {}
}