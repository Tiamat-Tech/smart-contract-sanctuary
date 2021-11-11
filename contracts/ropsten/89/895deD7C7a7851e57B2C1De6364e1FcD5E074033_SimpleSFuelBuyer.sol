// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import 'pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol';

contract SimpleSFuelBuyer {
    using SafeMath for uint256;

    address public superfuel;
    IPancakeRouter02 public pancakeRouter;

    bool private inSwap;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor(address sfuel, address router) public {
        superfuel = sfuel;
        pancakeRouter = IPancakeRouter02(router);
    }

    function swapCurrencyForTokens(uint256 amount, address destination) private lockTheSwap {
        // generate the pair path of token
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(superfuel);

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            destination,
            block.timestamp.add(400)
        );
    }

    function buySuperFuel(uint256 amount) public {
        if(!inSwap){
            swapCurrencyForTokens(amount, msg.sender);
        }
    }

    receive() external payable {
        buySuperFuel(msg.value);
    }

    fallback() external payable {
        buySuperFuel(msg.value);
    }

}