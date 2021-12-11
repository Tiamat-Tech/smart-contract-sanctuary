// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./IERC20.sol";
import "./IUniswapV2Router.sol";

contract TokenSwap {

    event Swap(address router, uint256 amount);

    address public admin;
    address public client;
    address public tok1;
    address public tok2;
    address public pair;
    address private weth;
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; //["0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"]

    uint256 MAX_INT = 2**256 - 1;

    constructor(address _weth, address _tok1, address _tok2, address _client) {
        weth = _weth;
        admin = msg.sender;
        tok1 = _tok1;
        tok2 = _tok2;
        client = _client;
    }

    modifier onlyOwner() {
        require(admin == msg.sender, "Ownable: caller is not the manager");
        _;
    }

    function approveRouter(address router) public onlyOwner {
        IERC20(tok1).approve(router, MAX_INT);
    }

    function disapproveRouter(address router) public onlyOwner {
        IERC20(tok1).approve(router, 0);
    }

    function swap(
        uint256 _amountIn,
        uint256 _amountOut,
        address tok1,
        address tok2,
        address[] memory _routers
    ) onlyOwner external {
        address[] memory path;
        if (tok1 == weth || tok2 == weth) {
            path = new address[](2);
            path[0] = tok1;
            path[1] = tok2;
        } else {
            path = new address[](3);
            path[0] = tok1;
            path[1] = weth;
            path[2] = tok2;
        }

        address router = address(0);
        uint256 amountOutMin = 0;

        for (uint256 i = 0; i < _routers.length; i++) {
            uint256[] memory amountOutMins = IUniswapV2Router(_routers[i])
                .getAmountsOut(_amountIn, path);
            if (amountOutMins[path.length - 1] > amountOutMin) {
                router = _routers[i];
                amountOutMin = amountOutMins[path.length - 1];
            }
        }
        require(_amountOut >= amountOutMin, "AmountOut is not a valid amount, make it bigger");
        IERC20(tok1).transferFrom(client, address(this), _amountIn);
        // IERC20(tok1).approve(router, _amountIn);
        uint256[] memory amounts = IUniswapV2Router(router)
            .swapExactTokensForTokens(
                _amountIn,
                amountOutMin,
                path,
                client,
                block.timestamp
            );

        uint256 amount = amounts[amounts.length - 1];

        emit Swap(router, amount);
    }
}