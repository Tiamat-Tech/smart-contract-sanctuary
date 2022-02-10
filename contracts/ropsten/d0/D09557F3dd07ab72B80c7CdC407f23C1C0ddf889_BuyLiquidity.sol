// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../Storage.sol";
import "./dex/IPair.sol";
import "./dex/IRouter.sol";

interface IPriceFeed {
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract BuyLiquidity is Ownable {
  /// @notice Storage contract
  Storage public info;

  /// @notice Treasury contract
  address payable public treasury;

  /// @notice Fee token to USD price feed contract
  IPriceFeed public priceFeed;

  struct Swap {
    address[] path;
    uint256 outMin;
  }

  event StorageChanged(address indexed info);

  event TreasuryChanged(address indexed treasury);

  event PriceFeedChanged(address indexed priceFeed);

  constructor(
    address _info,
    address payable _terasury,
    address _priceFeed
  ) {
    info = Storage(_info);
    treasury = _terasury;
    priceFeed = IPriceFeed(_priceFeed);
  }

  /**
   * @notice Change storage contract address.
   * @param _info New storage contract address.
   */
  function changeStorage(address _info) external onlyOwner {
    info = Storage(_info);
    emit StorageChanged(_info);
  }

  /**
   * @notice Change treasury contract address.
   * @param _treasury New treasury contract address.
   */
  function changeTreasury(address payable _treasury) external onlyOwner {
    treasury = _treasury;
    emit TreasuryChanged(treasury);
  }

  /**
   * @notice Change price feed contract address.
   * @param _priceFeed New price feed contract address.
   */
  function changePrireFeed(address _priceFeed) external onlyOwner {
    priceFeed = IPriceFeed(_priceFeed);
    emit PriceFeedChanged(_priceFeed);
  }

  function _swap(
    address router,
    uint256 amount,
    uint256 outMin,
    address[] memory path,
    uint256 deadline
  ) internal {
    if (path[0] == path[path.length - 1]) return;

    IRouter(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
      amount,
      outMin,
      path,
      address(this),
      deadline
    );
  }

  /**
   * @return Current call commission.
   */
  function fee() public view returns (uint256) {
    uint256 feeUSD = info.getUint(keccak256("DFH:Fee:Automate:BuyLiquidity"));
    if (feeUSD == 0) return 0;

    (, int256 answer, , , ) = priceFeed.latestRoundData();
    require(answer > 0, "BuyLiquidity::fee: invalid fee token price");

    return (feeUSD * (10**18)) / uint256(answer);
  }

  function buyLiquidity(
    uint256 amount,
    address router,
    Swap memory swap0,
    Swap memory swap1,
    IPair to,
    uint256 deadline
  ) external payable {
    require(
      info.getBool(keccak256(abi.encodePacked("DFH:Contract:BuyLiquidity:allowedRouter:", router))),
      "BuyLiquidity::buyLiquidity: invalid router address"
    );
    require(swap0.path[0] == swap1.path[0], "BuyLiquidity::buyLiqudity: start token not equals");

    // Pay commission
    uint256 payFee = fee();
    require(msg.value >= payFee, "BuyLiquidity::buyLiqudity: insufficient funds to pay commission");
    treasury.transfer(payFee);
    if (msg.value > payFee) {
      payable(msg.sender).transfer(msg.value - payFee);
    }

    // Get amount
    address token0 = to.token0();
    require(swap0.path[swap0.path.length - 1] == token0, "BuyLiquidity::buyLiqudity: invalid token0");
    address token1 = to.token1();
    require(swap1.path[swap1.path.length - 1] == token1, "BuyLiquidity::buyLiqudity: invalid token1");
    IERC20(swap0.path[0]).transferFrom(msg.sender, address(this), amount);
    IERC20(swap0.path[0]).approve(router, amount);

    // Swap tokens
    uint256 amount0In = amount / 2;
    _swap(router, amount0In, swap0.outMin, swap0.path, deadline);
    uint256 amount1In = amount - amount0In;
    _swap(router, amount1In, swap1.outMin, swap1.path, deadline);

    // Add liquidity
    amount0In = IERC20(token0).balanceOf(address(this));
    amount1In = IERC20(token1).balanceOf(address(this));
    IERC20(token0).approve(router, amount0In);
    IERC20(token1).approve(router, amount1In);
    IRouter(router).addLiquidity(token0, token1, amount0In, amount1In, 0, 0, msg.sender, deadline);

    // Return remainder
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