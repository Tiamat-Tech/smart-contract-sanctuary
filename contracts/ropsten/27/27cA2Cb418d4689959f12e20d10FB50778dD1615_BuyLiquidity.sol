// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Storage.sol";
import "./dex/IPair.sol";
import "./dex/IRouter.sol";

contract BuyLiquidity is Ownable {
  Storage public info;

  struct Swap {
    address[] path;
    uint256 outMin;
  }

  event StorageChanged(address info);

  constructor(address _info) {
    info = Storage(_info);
  }

  function changeStorage(address _info) external onlyOwner {
    require(_info != address(info), "BuyLiquidity::changeStorage: storage address not changed");

    info = Storage(_info);
    emit StorageChanged(_info);
  }

  function _swap(
    address router,
    uint256 amount,
    uint256 outMin,
    address[] memory path,
    uint256 deadline
  ) internal {
    IRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      amount,
      outMin,
      path,
      address(this),
      deadline
    );
  }

  function buyLiquidity(
    uint256 amount,
    address router,
    Swap memory swap0,
    Swap memory swap1,
    IPair to,
    uint256 deadline
  ) external {
    require(
      info.getBool(keccak256(abi.encodePacked("DFH:Contract:BuyLiquidity:allowedRouter:", router))),
      "BuyLiquidity::buyLiquidity: invalid router address"
    );
    require(swap0.path[0] == swap1.path[0], "BuyLiquidity::buyLiqudity: start token not equals");

    address token0 = to.token0();
    require(swap0.path[swap0.path.length - 1] == token0, "BuyLiquidity::buyLiqudity: invalid token0");
    address token1 = to.token1();
    require(swap1.path[swap1.path.length - 1] == token1, "BuyLiquidity::buyLiqudity: invalid token1");

    IERC20(swap0.path[0]).transferFrom(msg.sender, address(this), amount);
    IERC20(swap0.path[0]).approve(router, amount);

    uint256 amount0In = amount / 2;
    _swap(router, amount0In, swap0.outMin, swap0.path, deadline);
    uint256 amount1In = amount - amount0In;
    _swap(router, amount1In, swap1.outMin, swap1.path, deadline);

    amount0In = IERC20(token0).balanceOf(address(this));
    amount1In = IERC20(token1).balanceOf(address(this));
    IERC20(token0).approve(router, amount0In);
    IERC20(token1).approve(router, amount1In);
    IRouter(router).addLiquidity(token0, token1, amount0In, amount1In, 0, 0, msg.sender, deadline);

    uint256 tokenBalance = IERC20(token0).balanceOf(address(this));
    if (tokenBalance > 0) {
      IERC20(token0).transfer(msg.sender, tokenBalance);
    }
    tokenBalance = IERC20(token1).balanceOf(address(this));
    if (tokenBalance > 0) {
      IERC20(token1).transfer(msg.sender, tokenBalance);
    }
    tokenBalance = IERC20(swap0.path[0]).balanceOf(address(this));
    if (tokenBalance > 0) {
      IERC20(swap0.path[0]).transfer(msg.sender, tokenBalance);
    }
  }
}