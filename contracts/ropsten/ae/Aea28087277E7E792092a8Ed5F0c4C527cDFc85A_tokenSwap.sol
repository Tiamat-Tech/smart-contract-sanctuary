// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
import 'hardhat/console.sol';
import './IERC20.sol';
import './IUniswap.sol';
import './Ownable.sol';

contract tokenSwap is Ownable {

  address private UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address private UNISWAP_V2_ROUTER;
  address private WETH;
  address[] path;
  uint256 MAX = 115792089237316195423570985008687907853269984665640564039457584007913129639935;


  constructor (address _router, address _weth) {
    UNISWAP_V2_ROUTER = _router;
    WETH = _weth;
    IERC20(WETH).approve(UNISWAP_V2_ROUTER, MAX);
  }
  function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external onlyOwner {

  IERC20(_tokenIn).transferFrom(_msgSender(), address(this), _amountIn);

  address pairAddress = IUniswapV2Factory(UNISWAP_V2_FACTORY).getPair(_tokenIn, _tokenOut);
  console.log("Token pair address: %s", pairAddress);

  // IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, MAX);

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
  
  console.log('msg sender: %s', _msgSender());
  IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(_amountIn, 10, path, _msgSender(), block.timestamp);
  }

  function getTokenPrice(address _pairAddress) public view returns(uint)
   {
     //address _pairAddress, uint amount
    uint amount = 1;
    // address qq = 0xE8c6d3d1612cfD65e3D8fcAB3bA90D100029a79C; // weth dai
    IUniswapV2Pair pair = IUniswapV2Pair(_pairAddress);
    IERC20 token1 = IERC20(pair.token1());
    (uint Res0, uint Res1,) = pair.getReserves();

    // decimals
    uint res0 = Res0*(10**token1.decimals());
    return((amount*res0)/Res1); // return amount of token0 needed to buy token1
   }
}