//SPDX-License-Identifier: Unlicense

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../base/interface/IGovernable.sol";
import "../base/governance/Controllable.sol";
import "../third_party/uniswap/IUniswapV2Factory.sol";
import "../third_party/uniswap/IUniswapV2Pair.sol";
import "./IPriceCalculator.sol";
import "../base/interface/ISmartVault.sol";

pragma solidity 0.7.6;

contract PriceCalculatorMatic is IGovernable, Initializable, Controllable, IPriceCalculator {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 constant public PRECISION_DECIMALS = 18;
  uint256 constant public DEPTH = 20;
  // USDC is default
  address  constant public DEFAULT_BASE_TOKEN = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;

  // Addresses for factories and registries for different DEX platforms.
  // Functions will be added to allow to alter these when needed.
  address[] public swapFactories;
  // Symbols for detecting platforms
  string[] public swapLpNames;

  //Key tokens are used to find liquidity for any given token on Swap platforms.
  address[] public keyTokens;

  event KeyTokenAdded(address newKeyToken);
  event KeyTokenRemoved(address keyToken);
  event SwapPlatformAdded(address factoryAddress, string name);
  event SwapPlatformRemoved(address factoryAddress, string name);

  function initialize(address _controller) public initializer {
    Controllable.initializeControllable(_controller);
    //USDC
    addKeyToken(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    //WETH
    addKeyToken(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    //DAI
    addKeyToken(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    //USDT
    addKeyToken(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    //WBTC
    addKeyToken(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);

    // quickswap
    addSwapPlatform(0x5757371414417b8C6CAad45bAeF941aBc7d3Ab32, "Uniswap V2");
    // sushiswap
    addSwapPlatform(0xc35DADB65012eC5796536bD9864eD8773aBc74C4, "SushiSwap LP Token");
  }

  function getPriceWithDefaultOutput(address token) external view override returns (uint256) {
    return getPrice(token, DEFAULT_BASE_TOKEN);
  }

  //Main function of the contract. Gives the price of a given token in the defined output token.
  //The contract allows for input tokens to be LP tokens from Uniswap forks.
  //In case of LP token, the underlying tokens will be found and valued to get the price.
  // Output token should exist int the keyTokenList
  function getPrice(address token, address outputToken) public view override returns (uint256) {
    if (token == outputToken) {
      return (10 ** PRECISION_DECIMALS);
    }

    uint256 rate = 1;
    uint256 rateDenominator = 1;
    // check if it is a vault need to return the underlying price
    if (IController(controller()).vaults(token)) {
      rate = ISmartVault(token).getPricePerFullShare();
      token = ISmartVault(token).underlying();
      rateDenominator = ERC20(token).decimals();
    }
    uint256 price;
    if (isSwapPlatform(token)) {
      address[2] memory tokens;
      uint256[2] memory amounts;
      (tokens, amounts) = getLpUnderlying(token);
      for (uint256 i = 0; i < 2; i++) {
        address[DEPTH] memory usedLps;
        uint256 priceToken = computePrice(tokens[i], outputToken, usedLps, 0);
        if (priceToken == 0) {
          return 0;
        }
        uint256 tokenValue = priceToken * amounts[i] / 10 ** PRECISION_DECIMALS;
        price += tokenValue;
      }
    } else {
      address[DEPTH] memory usedLps;
      price = computePrice(token, outputToken, usedLps, 0);
    }

    return price.mul(rate).div(rateDenominator);
  }

  //Checks if address is Uni or Sushi LP. This is done in two steps,
  //because the second step seems to cause errors for some tokens.
  //Only the first step is not deemed accurate enough, as any token could be called UNI-V2.
  function isSwapPlatform(address token) public view returns (bool) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
    string memory name = pair.name();

    for (uint i; i < swapFactories.length; i++) {
      if (isEqualString(name, swapLpNames[i])) {
        return checkFactory(pair, swapFactories[i]);
      }
    }
    return false;
  }

  function isEqualString(string memory arg1, string memory arg2) internal pure returns (bool) {
    bool check = (keccak256(abi.encodePacked(arg1)) == keccak256(abi.encodePacked(arg2))) ? true : false;
    return check;
  }

  /* solhint-disable no-unused-vars */
  function checkFactory(IUniswapV2Pair pair, address compareFactory) public view returns (bool) {
    try pair.factory{gas : 3000}() returns (address factory) {
      bool check = (factory == compareFactory) ? true : false;
      return check;
    } catch {}
    return false;
  }

  //Get underlying tokens and amounts for LP
  function getLpUnderlying(address lpAddress) public view returns (address[2] memory, uint256[2] memory) {
    IUniswapV2Pair lp = IUniswapV2Pair(lpAddress);
    address[2] memory tokens;
    uint256[2] memory amounts;
    tokens[0] = lp.token0();
    tokens[1] = lp.token1();
    uint256 token0Decimals = ERC20(tokens[0]).decimals();
    uint256 token1Decimals = ERC20(tokens[1]).decimals();
    uint256 supplyDecimals = lp.decimals();
    (uint256 reserve0, uint256 reserve1,) = lp.getReserves();
    uint256 totalSupply = lp.totalSupply();
    if (reserve0 == 0 || reserve1 == 0 || totalSupply == 0) {
      amounts[0] = 0;
      amounts[1] = 0;
      return (tokens, amounts);
    }
    amounts[0] = reserve0 * 10 ** (supplyDecimals - token0Decimals + PRECISION_DECIMALS) / totalSupply;
    amounts[1] = reserve1 * 10 ** (supplyDecimals - token1Decimals + PRECISION_DECIMALS) / totalSupply;
    return (tokens, amounts);
  }

  //General function to compute the price of a token vs the defined output token.
  function computePrice(address token, address outputToken, address[DEPTH] memory usedLps, uint256 deep)
  public view returns (uint256) {
    if (token == outputToken) {
      return 10 ** PRECISION_DECIMALS;
    } else if (token == address(0)) {
      return 0;
    }

    require(deep <= usedLps.length, "too deep");

    (address keyToken,, address lpAddress) = getLargestPool(token, usedLps, deep);
    require(lpAddress != address(0), "key lp not found");
    usedLps[deep] = lpAddress;
    deep++;

    uint256 lpPrice = getPriceFromLp(lpAddress, token);
    uint256 keyTokenPrice = computePrice(keyToken, outputToken, usedLps, deep);
    return lpPrice * keyTokenPrice / 10 ** PRECISION_DECIMALS;
  }

  // Gives the LP with largest liquidity for a given token
  // and a given tokenset (either keyTokens or pricingTokens)
  function getLargestPool(address token, address[DEPTH] memory usedLps, uint256 deep)
  public view returns (address, uint256, address) {
    uint256 largestLpSize;
    address largestKeyToken;
    uint256 largestPlatformIdx;
    address lpAddress;
    for (uint256 i = 0; i < keyTokens.length; i++) {
      for (uint256 j = 0; j < swapFactories.length; j++) {
        (uint256 poolSize, address lp) = getLpForFactory(swapFactories[j], token, keyTokens[i]);

        if (isUsed(usedLps, deep, lp)) {
          continue;
        }

        if (poolSize > largestLpSize) {
          largestLpSize = poolSize;
          largestKeyToken = keyTokens[i];
          largestPlatformIdx = j;
          lpAddress = lp;
        }
      }
    }
    return (largestKeyToken, largestPlatformIdx, lpAddress);
  }

  function isUsed(address[DEPTH] memory usedLps, uint256 deep, address lp) internal pure returns (bool) {
    for (uint256 d = 0; d < deep; d++) {
      if (usedLps[d] == lp) {
        return true;
      }
    }
    return false;
  }

  function getLpForFactory(address _factory, address token0, address token1)
  private view returns (uint256, address){
    address pairAddress = IUniswapV2Factory(_factory).getPair(token0, token1);
    if (pairAddress != address(0)) {
      return (getLpSize(pairAddress, token0), pairAddress);
    }
    return (0, address(0));
  }

  function getLpSize(address pairAddress, address token) public view returns (uint256) {
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    address token0 = pair.token0();
    (uint112 poolSize0, uint112 poolSize1,) = pair.getReserves();
    uint256 poolSize = (token == token0) ? poolSize0 : poolSize1;
    return poolSize;
  }

  //Generic function giving the price of a given token vs another given token on Swap platform.
  function getPriceFromLp(address lpAddress, address token) public view returns (uint256) {
    IUniswapV2Pair pair = IUniswapV2Pair(lpAddress);
    address token0 = pair.token0();
    address token1 = pair.token1();
    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();

    // both reserves should have the same decimals
    reserve0 = reserve0.mul(10 ** PRECISION_DECIMALS).div(10 ** token0Decimals);
    reserve1 = reserve1.mul(10 ** PRECISION_DECIMALS).div(10 ** token1Decimals);

    if (token == token0) {
      return reserve1
      .mul(10 ** PRECISION_DECIMALS)
      .div(reserve0);
    } else {
      return reserve0
      .mul(10 ** PRECISION_DECIMALS)
      .div(reserve1);
    }
  }

  //Checks if a given token is in the keyTokens list.
  function isKeyToken(address token) public view returns (bool) {
    for (uint256 i = 0; i < keyTokens.length; i++) {
      if (token == keyTokens[i]) {
        return true;
      }
    }
    return false;
  }

  function isSwapFactoryToken(address adr) public view returns (bool) {
    for (uint256 i = 0; i < swapFactories.length; i++) {
      if (adr == swapFactories[i]) {
        return true;
      }
    }
    return false;
  }

  function isSwapName(string memory name) public view returns (bool) {
    for (uint256 i = 0; i < swapLpNames.length; i++) {
      if (isEqualString(name, swapLpNames[i])) {
        return true;
      }
    }
    return false;
  }

  function keyTokensSize() public view returns (uint256) {
    return keyTokens.length;
  }

  function swapFactoriesSize() public view returns (uint256) {
    return swapFactories.length;
  }

  function isGovernance(address _contract) external override view returns (bool) {
    return IController(controller()).isGovernance(_contract);
  }

  // ************* INTERNAL *****************

  function removeFromKeyTokens(uint256 index) internal {
    require(index < keyTokens.length, "wrong index");

    for (uint256 i = index; i < keyTokens.length - 1; i++) {
      keyTokens[i] = keyTokens[i + 1];
    }
    keyTokens.pop();
  }

  function removeFromSwapFactories(uint index) internal {
    require(index < swapFactories.length, "wrong index");

    for (uint i = index; i < swapFactories.length - 1; i++) {
      swapFactories[i] = swapFactories[i + 1];
    }
    swapFactories.pop();
  }

  function removeFromSwapNames(uint index) internal {
    require(index < swapLpNames.length, "wrong index");

    for (uint i = index; i < swapLpNames.length - 1; i++) {
      swapLpNames[i] = swapLpNames[i + 1];
    }
    swapLpNames.pop();
  }

  // ************* GOVERNANCE ACTIONS ***************

  function addKeyToken(address newToken) public onlyGovernance {
    require((isKeyToken(newToken) == false), "already have");
    keyTokens.push(newToken);
    emit KeyTokenAdded(newToken);
  }

  function removeKeyToken(address keyToken) external onlyGovernance {
    require(isKeyToken(keyToken), "not key");
    uint256 i;
    for (i = 0; i < keyTokens.length; i++) {
      if (keyToken == keyTokens[i]) {
        break;
      }
    }
    removeFromKeyTokens(i);
    emit KeyTokenRemoved(keyToken);
  }

  function addSwapPlatform(address _factoryAddress, string memory _name) public onlyGovernance {
    for (uint256 i; i < swapFactories.length; i++) {
      require(swapFactories[i] != _factoryAddress, "factory already exist");
      require(!isEqualString(swapLpNames[i], _name), "name already exist");
    }
    swapFactories.push(_factoryAddress);
    swapLpNames.push(_name);
    emit SwapPlatformAdded(_factoryAddress, _name);
  }

  function removeSwapPlatform(address _factoryAddress, string memory _name) external onlyGovernance {
    require(isSwapFactoryToken(_factoryAddress), "swap not exist");
    require(isSwapName(_name), "name not exist");
    uint256 i;
    for (i = 0; i < swapFactories.length; i++) {
      if (_factoryAddress == swapFactories[i]) {
        break;
      }
    }
    removeFromSwapFactories(i);

    for (i = 0; i < swapLpNames.length; i++) {
      if (isEqualString(_name, swapLpNames[i])) {
        break;
      }
    }
    removeFromSwapNames(i);
    emit SwapPlatformRemoved(_factoryAddress, _name);
  }
}