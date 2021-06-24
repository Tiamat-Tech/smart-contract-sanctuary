//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "../base/governance/Controllable.sol";
import "../base/interface/IGovernable.sol";
import "../third_party/uniswap/IUniswapV2Pair.sol";
import "../third_party/uniswap/IUniswapV2Router02.sol";
import "hardhat/console.sol";

contract LiquidityBalancer is IGovernable, Controllable {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  string public constant VERSION = "0";
  uint256 constant internal PRECISION = 10 ** 18;
  uint256 constant internal  UPDATE_NUMERATOR = 10;
  uint256 constant internal  UPDATE_DENOMINATOR = 1000;

  mapping(address => uint256) public priceTargets;
  mapping(address => uint256) public lpTvlTargets;
  mapping(address => address) public routers;
  address[] internal route;

  event PriceTargetChanged(address token, uint256 target);
  event LpTvlTargetChanged(address lp, uint256 target);
  event RouterChanged(address lp, address router);
  event Swap(address tokenIn, address tokenOut, uint256 amount);
  event LiqAdded(address lp, uint256 amount0, uint256 amount1);
  event LiqRemoved(address lp, uint256 amount);

  constructor(address _controller) {
    Controllable.initializeControllable(_controller);
  }

  function changeLiquidity(address _token, address _lp)
  public onlyHardWorkerOrGovernance {
    require(priceTargets[_token] != 0, "zero price target");
    require(lpTvlTargets[_lp] != 0, "zero lp tvl target");

    IUniswapV2Pair pair = IUniswapV2Pair(_lp);
    address oppositeToken = (_token == pair.token0()) ? pair.token1() : pair.token0();

    uint256 sellAmount = needToSell(_token, _lp);
    uint256 remAmount = needToRemove(_token, _lp);

    if (remAmount > 0) {
      removeLiquidity(_lp, remAmount, _token, oppositeToken);
      // buy target tokens
      route.push(oppositeToken);
      route.push(_token);
      swap(
        routers[_lp],
        route,
        IERC20(oppositeToken).balanceOf(address(this))
      );
      route.pop();
      route.pop();
      updateLpTvlTarget(_lp);
    } else if (sellAmount > 0) {
      // sell target token for opposite token
      route.push(_token);
      route.push(oppositeToken);
      swap(
        routers[_lp],
        route,
        sellAmount
      );
      route.pop();
      route.pop();
      addLiquidity(_lp, _token, oppositeToken);
      updatePriceTarget(_token);
    }
  }

  function needToSell(address _token, address _lp) public view returns (uint256) {
    uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
    (, uint256 oppositeReserve, uint256 price, uint256 tokenReserve) = getLpInfo(_lp, _token);

    uint256 sellAmount = computeSellAmount(tokenReserve, oppositeReserve, priceTargets[_token]);

    console.log("output", computeOutputAmount(tokenReserve, oppositeReserve, sellAmount));
    console.log("need to add liq", computeOutputAmount(tokenReserve, oppositeReserve, sellAmount)
    .mul(PRECISION).div(priceTargets[_token]));

    uint256 sellCap = 0;
    // not enough money
    if (tokenBalance > sellAmount) {
      uint256 needForAddingLiq = computeOutputAmount(tokenReserve, oppositeReserve, sellAmount)
      .mul(PRECISION).div(priceTargets[_token]);
      uint256 balAfterSwap = tokenBalance.sub(sellAmount);
      // after the sell we will not have enough money for adding the liquidity
      // don't sell in this case
      // need to create an accurate amount computation
      if (balAfterSwap > needForAddingLiq) {
        sellCap = balAfterSwap.sub(needForAddingLiq);
      }
    }


    console.log("sellCap", sellCap);
    // after swap you should have amount for adding liquidity
    sellAmount = Math.min(sellAmount, sellCap);

    if (sellAmount > 0 && price > priceTargets[_token]) {
      // don't sell more than a half for adding a liquidity after sell
      return Math.min(sellAmount, sellCap);
    } else {
      return 0;
    }
  }

  function needToRemove(address _token, address _lp) public view returns (uint256) {
    uint256 lpBalance = IERC20(_lp).balanceOf(address(this));
    (, uint256 oppositeTokenStacked, ,) = getLpInfo(_lp, _token);
    uint256 currentTvl = oppositeTokenStacked.mul(2);

    uint256 remAmount = computeRemAmount(currentTvl, _lp);
    remAmount = Math.min(remAmount, lpBalance);

    if (remAmount > 0 && lpBalance >= remAmount && currentTvl > lpTvlTargets[_lp]) {
      return Math.min(remAmount, lpBalance);
    } else {
      return 0;
    }
  }

  function computeSellAmount(
    uint256 tokenReserve,
    uint256 oppositeReserve,
    uint256 targetPrice
  ) internal pure returns (uint256) {
    if (targetPrice == 0) {
      return 0;
    }
    // ignore fees
    uint base = oppositeReserve.mul(tokenReserve).div(targetPrice).mul(PRECISION);
    uint256 sqrtBase = sqrt(base);
    if (sqrtBase < tokenReserve) {
      // in this case the price lower than target price, need to sell
      return 0;
    }
    return sqrtBase.sub(tokenReserve);
  }

  function computeOutputAmount(
    uint256 tokenReserve,
    uint256 oppositeReserve,
    uint256 inputAmount
  ) internal view returns (uint256){
    console.log("computeOutputAmount", inputAmount.mul(oppositeReserve), tokenReserve.add(inputAmount), inputAmount.mul(oppositeReserve).div(tokenReserve.add(inputAmount)));
    return inputAmount.mul(oppositeReserve).div(tokenReserve.add(inputAmount));
  }

  function computeRemAmount(uint256 currentTvl, address _lp) internal view returns (uint256) {
    if (currentTvl < lpTvlTargets[_lp]) {
      // no remove require
      return 0;
    }
    uint256 remAmountRate = currentTvl.sub(lpTvlTargets[_lp]).mul(PRECISION).div(currentTvl);
    return ERC20(address(_lp)).totalSupply().mul(remAmountRate).div(PRECISION);
  }

  function updateLpTvlTarget(address _lp) internal {
    lpTvlTargets[_lp] += lpTvlTargets[_lp].mul(UPDATE_NUMERATOR).div(UPDATE_DENOMINATOR);
  }

  function updatePriceTarget(address _token) internal {
    priceTargets[_token] += priceTargets[_token].mul(UPDATE_NUMERATOR).div(UPDATE_DENOMINATOR);
  }

  // https://uniswap.org/docs/v2/smart-contracts/router02/#swapexacttokensfortokens
  function swap(address _router, address[] memory _route, uint256 _amount) internal {
    require(_router != address(0), "zero router");
    uint256 bal = IERC20(_route[0]).balanceOf(address(this));
    require(bal >= _amount, "not enough balance");
    IERC20(_route[0]).safeApprove(_router, 0);
    IERC20(_route[0]).safeApprove(_router, _amount);
    IUniswapV2Router02(_router).swapExactTokensForTokens(
      _amount,
      0,
      _route,
      address(this),
      block.timestamp
    );
    emit Swap(_route[0], _route[1], _amount);
  }

  function addLiquidity(address _lp, address token, address oppositeToken) internal {
    address routerAddress = routers[_lp];
    IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

    uint256 amount0 = IERC20(token).balanceOf(address(this));
    uint256 amount1 = IERC20(oppositeToken).balanceOf(address(this));

    IERC20(token).approve(routerAddress, 0);
    IERC20(token).approve(routerAddress, amount0);
    IERC20(oppositeToken).approve(routerAddress, 0);
    IERC20(oppositeToken).approve(routerAddress, amount1);

    router.addLiquidity(
      token,
      oppositeToken,
      amount0,
      amount1,
      1,
      1,
      address(this),
      block.timestamp
    );
    console.log("opp bal", amount1, IERC20(oppositeToken).balanceOf(address(this)));
    require(IERC20(oppositeToken).balanceOf(address(this)) == 0, "added not all");
    emit LiqAdded(_lp, amount0, amount1);
  }

  function removeLiquidity(address _lp, uint256 _amount, address token0, address token1) internal {
    uint256 bal = IERC20(_lp).balanceOf(address(this));
    require(bal >= _amount, "not enough balance");
    address routerAddress = routers[_lp];
    IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

    IERC20(_lp).approve(routerAddress, 0);
    IERC20(_lp).approve(routerAddress, _amount);

    router.removeLiquidity(
      token0,
      token1,
      _amount,
      1,
      1,
      address(this),
      block.timestamp
    );

    emit LiqRemoved(_lp, _amount);
  }

  function getLpInfo(address pairAddress, address targetToken)
  internal view returns (address oppositeToken, uint256 oppositeTokenStacked, uint256 price, uint256 tokenStacked) {
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    address token0 = pair.token0();
    address token1 = pair.token1();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();

    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();

    // both reserves should have the same decimals
    reserve0 = reserve0.mul(PRECISION).div(10 ** token0Decimals);
    reserve1 = reserve1.mul(PRECISION).div(10 ** token1Decimals);

    tokenStacked = (targetToken == token0) ? reserve0 : reserve1;
    oppositeTokenStacked = (targetToken == token0) ? reserve1 : reserve0;
    oppositeToken = (targetToken == token0) ? token1 : token0;

    if (targetToken == token0) {
      price = reserve1
      .mul(PRECISION)
      .div(reserve0);
    } else {
      price = reserve0
      .mul(PRECISION)
      .div(reserve1);
    }
    return (oppositeToken, oppositeTokenStacked, price, tokenStacked);
  }

  // uniswap square root implementation
  // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
  function sqrt(uint256 y) internal pure returns (uint256 z) {
    if (y > 3) {
      z = y;
      uint256 x = y.div(2).add(1);
      while (x < z) {
        z = x;
        x = y.div(x).add(x).div(2);
      }
    } else if (y != 0) {
      z = 1;
    }
    return z;
  }

  // ************** VIEWS ********************

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  // ***************** GOVERNANCE ACTIONS *********************

  function salvage(address _token) public onlyGovernance {
    uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
    if (tokenBalance > 0) {
      IERC20(_token).safeTransfer(msg.sender, tokenBalance);
    }
  }

  // should have PRECISION_DECIMALS
  function setTargetPrice(address _token, uint256 _target) external onlyGovernance {
    require(_target != 0, "wrong target");
    require(_token != address(0), "wrong token");
    priceTargets[_token] = _target;
    emit PriceTargetChanged(_token, _target);
  }

  // should have PRECISION_DECIMALS
  function setTargetLpTvl(address _lp, uint256 _target) external onlyGovernance {
    require(_target != 0, "wrong target");
    require(_lp != address(0), "wrong lp");
    lpTvlTargets[_lp] = _target;
    emit LpTvlTargetChanged(_lp, _target);
  }

  function setRouter(address _lp, address _router) external onlyGovernance {
    require(_lp != address(0), "wrong lp");
    require(_router != address(0), "wrong router");
    routers[_lp] = _router;
    emit RouterChanged(_lp, _router);
  }

}