import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./interface/uniswap/IUniswapV2Factory.sol";
import "./interface/uniswap/IUniswapV2Pair.sol";
import "./Governable.sol";

pragma solidity 0.6.12;

contract OracleRopsten is Governable {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  //Addresses for factories and registries for different DEX platforms. Functions will be added to allow to alter these when needed.
  address public uniswapFactoryAddress = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address public sushiswapFactoryAddress = 0xaDe0ad525430cfe17218B679483c46B6c1d63fe2;
  uint256 public precisionDecimals = 18;

  IUniswapV2Factory uniswapFactory = IUniswapV2Factory(uniswapFactoryAddress);
  IUniswapV2Factory sushiswapFactory = IUniswapV2Factory(sushiswapFactoryAddress);

  //Key tokens are used to find liquidity for any given token on Uni, Sushi and Curve.
  address[] public keyTokens = [
  0xc778417E063141139Fce010982780140Aa0cD5Ab, //WETH
  0xaD6D458402F60fD3Bd25163575031ACDce07538D, //DAI
  0xc3778758D19A654fA6d0bb3593Cf26916fB3d114, //WBTC
  0xDBC941fEc34e8965EbC4A25452ae7519d6BDfc4e  //USDC
  ];
  //Pricing tokens are Key tokens with good liquidity with the defined output token on Uniswap.
  address[] public pricingTokens = [
  0xc778417E063141139Fce010982780140Aa0cD5Ab, //WETH
  0xaD6D458402F60fD3Bd25163575031ACDce07538D //DAI
  ];
  //The defined output token is the unit in which prices of input tokens are given.
  address public definedOutputToken = 0xaD6D458402F60fD3Bd25163575031ACDce07538D; //USDC
  uint256 public pricingTreshold = 0; //Tokens that have Uniswap pool with more than 5 million USDC (so >$10m total in LP) get added to pricingTokens.

  modifier validKeyToken(address keyToken){
      require(checkKeyToken(keyToken), "Not a Key Token");
      _;
  }
  modifier validPricingToken(address pricingToken){
      require(checkPricingToken(pricingToken), "Not a Pricing Token");
      _;
  }

  event FactoryChanged(address newFactory, address oldFactory);
  event RegistryChanged(address newRegistry, address oldRegistry);
  event KeyTokenAdded(address newKeyToken);
  event PricingTokenAdded(address newPricingToken);
  event KeyTokenRemoved(address keyToken);
  event PricingTokenRemoved(address pricingToken);
  event DefinedOutuptChanged(address newOutputToken, address oldOutputToken, uint256 pricingTreshold);

  constructor(address _storage)
  Governable(_storage) public {}

  function changeUniFactory(address newFactory) external onlyGovernance {
    address oldFactory = uniswapFactoryAddress;
    uniswapFactoryAddress = newFactory;
    uniswapFactory = IUniswapV2Factory(uniswapFactoryAddress);
    emit FactoryChanged(newFactory, oldFactory);
  }
  function changeSushiFactory(address newFactory) external onlyGovernance {
    address oldFactory = sushiswapFactoryAddress;
    sushiswapFactoryAddress = newFactory;
    sushiswapFactory = IUniswapV2Factory(sushiswapFactoryAddress);
    emit FactoryChanged(newFactory, oldFactory);
  }

  function addKeyToken(address newToken) external onlyGovernance {
    keyTokens.push(newToken);
    emit KeyTokenAdded(newToken);
    address pairAddress = uniswapFactory.getPair(newToken,definedOutputToken);
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    (uint112 reserve0, uint112 reserve1, uint32 unused) = pair.getReserves();
    uint256 decimals = ERC20(definedOutputToken).decimals();
    address token0 = pair.token0();
    if (token0 == definedOutputToken) {
      if (reserve0 > pricingTreshold*10**decimals) {
        addPricingToken(newToken);
      }
    } else {
      if (reserve1 > pricingTreshold*10**decimals) {
        addPricingToken(newToken);
      }
    }
  }
  function addPricingToken(address newToken) public onlyGovernance validKeyToken(newToken) {
    pricingTokens.push(newToken);
    emit PricingTokenAdded(newToken);
  }

  function removeKeyToken(address keyToken) external onlyGovernance validKeyToken(keyToken) {
    uint256 i;
    for ( i=0;i<keyTokens.length;i++) {
      if (keyToken == keyTokens[i]){
        break;
      }
    }
    while (i<keyTokens.length-1) {
      keyTokens[i] = keyTokens[i+1];
      i++;
    }
    keyTokens.pop();

    emit KeyTokenRemoved(keyToken);

    if (checkPricingToken(keyToken)) {
      removePricingToken(keyToken);
    }
  }
  function removePricingToken(address pricingToken) public onlyGovernance validPricingToken(pricingToken) {
    uint256 i;
    for (i=0;i<pricingTokens.length;i++) {
      if (pricingToken == pricingTokens[i]){
        break;
      }
    }
    while (i<pricingTokens.length-1) {
      pricingTokens[i] = pricingTokens[i+1];
      i++;
    }
    pricingTokens.pop();

    emit PricingTokenRemoved(pricingToken);
  }
  function changeDefinedOutput(address newOutputToken, uint256 newPricingTreshold) external onlyGovernance {
    address oldOutputToken = definedOutputToken;
    definedOutputToken = newOutputToken;
    pricingTreshold = newPricingTreshold;
    emit DefinedOutuptChanged(newOutputToken, oldOutputToken, newPricingTreshold);
    uint256 i;
    for (i=0;i<pricingTokens.length;i++) {
      address token = pricingTokens[i];
      if (token == newOutputToken) {
        continue;
      }
      (uint256 unused, uint256 liquidity) = getUniLiquidity(token,newOutputToken);
      if (liquidity < newPricingTreshold*10**precisionDecimals) {
        removePricingToken(token);
      }
    }
    for (i=0;i<keyTokens.length;i++) {
      address token = keyTokens[i];
      if (token == newOutputToken){
        if (checkPricingToken(token)) {
          continue;
        } else {
          addPricingToken(token);
        }
      }
      if (checkPricingToken(token)) {
        continue;
      } else {
        (uint256 unused, uint256 liquidity) = getUniLiquidity(token,newOutputToken);
        if (liquidity >= newPricingTreshold*10**precisionDecimals) {
          addPricingToken(token);
        }
      }
    }
  }

  //Main function of the contract. Gives the price of a given token in the defined output token.
  //The contract allows for input tokens to be LP tokens from Uniswap, Sushiswap, Curve and 1Inch.
  //In case of LP token, the underlying tokens will be found and valued to get the price.
  function getPrice(address token) external view returns (uint256) {
    if (token == definedOutputToken) {
      return (10**precisionDecimals);
    }
    bool uniSushiLP;
    uniSushiLP = isLPCheck(token);
    if (uniSushiLP) {
      address[2] memory tokens;
      uint256[2] memory amounts;
      (tokens, amounts) = getUniUnderlying(token);
      uint256 priceToken;
      uint256 tokenValue;
      uint256 price = 0;
      uint256 i;
      for (i=0;i<2;i++) {
        priceToken = computePrice(tokens[i]);
        if (priceToken == 0) {
          price = 0;
          return price;
        }
        tokenValue = priceToken*amounts[i]/10**precisionDecimals;
        price = price + tokenValue;
      }
      return price;
    } else {
      uint256 price = computePrice(token);
      return price;
    }
  }

  function isLPCheck(address token) public view returns(bool) {
    bool isUniSushi = isUniCheck(token) || isSushiCheck(token);
    return (isUniSushi);
  }

  //Checks if address is Uni LP. This is done in two steps, because the second step seems to cause errors for some tokens.
  //Only the first step is not deemed accurate enough, as any token could be caalled UNI-V2.
  function isUniCheck(address token) public view returns (bool) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
    string memory uniSymbol = "UNI-V2";
    try pair.symbol() returns (string memory symbol) {
      if (keccak256(abi.encodePacked(symbol)) != keccak256(abi.encodePacked(uniSymbol))) {
        return false;
      }
    } catch {
      return false;
    }
    try pair.factory{gas: 3000}() returns (address factory) {
      if (factory == uniswapFactoryAddress){
        return true;
      } else {
        return false;
      }
    } catch {
      return false;
    }
  }

  //Checks if address is Sushi LP.
  function isSushiCheck(address token) public view returns (bool) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
    string memory sushiSymbol = "SLP";
    try pair.symbol() returns (string memory symbol) {
      if (keccak256(abi.encodePacked(symbol)) != keccak256(abi.encodePacked(sushiSymbol))) {
        return false;
      }
    } catch {
      return false;
    }
    try pair.factory{gas:3000}() returns (address factory) {
      if (factory == sushiswapFactoryAddress){
        return true;
      } else {
        return false;
      }
    } catch {
      return false;
    }
  }

  //Get underlying tokens and amounts for Uni/Sushi LPs
  function getUniUnderlying(address token) public view returns (address[2] memory, uint256[2] memory) {
    IUniswapV2Pair pair = IUniswapV2Pair(token);
    address[2] memory tokens;
    uint256[2] memory amounts;
    tokens[0] = pair.token0();
    tokens[1] = pair.token1();
    uint256 token0Decimals = ERC20(tokens[0]).decimals();
    uint256 token1Decimals = ERC20(tokens[1]).decimals();
    uint256 supplyDecimals = ERC20(token).decimals();
    (uint256 reserve0, uint256 reserve1, uint32 unused) = pair.getReserves();
    uint256 totalSupply = pair.totalSupply();
    if (reserve0 == 0 || reserve1 == 0 || totalSupply == 0) {
      amounts[0] = 0;
      amounts[1] = 0;
      return (tokens, amounts);
    }
    amounts[0] = reserve0*10**(supplyDecimals-token0Decimals+precisionDecimals)/totalSupply;
    amounts[1] = reserve1*10**(supplyDecimals-token1Decimals+precisionDecimals)/totalSupply;
    return (tokens, amounts);
  }

  //General function to compute the price of a token vs the defined output token.
  function computePrice(address token) public view returns (uint256) {
    uint256 price;
    if (token == definedOutputToken) {
      price = 10**precisionDecimals;
    } else if (token == address(0)) {
      price = 0;
    } else {
      (address keyToken, address pool, bool uni, bool sushi) = getLargestPool(token,keyTokens);
      if (keyToken == address(0)) {
        price = 0;
      } else if (uni) {
        uint256 priceVsKeyToken = getPriceVsTokenUni(token,keyToken);
        uint256 keyTokenPrice = getKeyTokenPrice(keyToken);
        price = priceVsKeyToken*keyTokenPrice/10**precisionDecimals;
      } else if (sushi) {
        uint256 priceVsKeyToken = getPriceVsTokenSushi(token,keyToken);
        uint256 keyTokenPrice = getKeyTokenPrice(keyToken);
        price = priceVsKeyToken*keyTokenPrice/10**precisionDecimals;
      }
    }
    return (price);
  }

  //Checks the results of the different largest pool functions and returns the largest.
  function getLargestPool(address token, address[] memory tokenList) public view returns (address, address, bool, bool) {
    (address uniKeyToken, uint256 uniLiquidity) = getUniLargestPool(token, tokenList);
    (address sushiKeyToken, uint256 sushiLiquidity) = getSushiLargestPool(token, tokenList);
    if (uniLiquidity > sushiLiquidity) {
      return (uniKeyToken, address(0), true, false);
    } else {
      return (sushiKeyToken, address(0), false, true);
    }
  }

  //Gives the Uniswap pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  function getUniLargestPool(address token, address[] memory tokenList) public view returns (address, uint256) {
    uint256 largestPoolSize = 0;
    address largestPoolAddress;
    address largestKeyToken;
    uint256 poolSize;
    uint256 unused1;
    uint256 unused2;
    uint256 i;
    uint256 decimals = ERC20(token).decimals();
    for (i=0;i<tokenList.length;i++) {
      address pairAddress = uniswapFactory.getPair(token,tokenList[i]);
      if (pairAddress==address(0)) {
        continue;
      }
      IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
      address token0 = pair.token0();
      if (token == token0) {
        (poolSize, unused1, unused2) = pair.getReserves();
      } else {
        (unused1, poolSize, unused2) = pair.getReserves();
      }
      if (poolSize > largestPoolSize) {
        largestPoolSize = poolSize;
        largestKeyToken = tokenList[i];
        largestPoolAddress = pairAddress;
      }
    }
    if (largestPoolSize < 10**decimals) {
      return (address(0), 0);
    }
    return (largestKeyToken, largestPoolSize);
  }

  //Gives the Sushiswap pool with largest liquidity for a given token and a given tokenset (either keyTokens or pricingTokens)
  function getSushiLargestPool(address token, address[] memory tokenList) public view returns (address, uint256) {
    uint256 largestPoolSize = 0;
    address largestPoolAddress;
    address largestKeyToken;
    uint256 poolSize;
    uint256 unused1;
    uint256 unused2;
    uint256 i;
    uint256 decimals = ERC20(token).decimals();
    for (i=0;i<tokenList.length;i++) {
      address pairAddress = sushiswapFactory.getPair(token,tokenList[i]);
      if (pairAddress==address(0)) {
        continue;
      }
      IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
      address token0 = pair.token0();
      if (token == token0) {
        (poolSize, unused1, unused2) = pair.getReserves();
      } else {
        (unused1, poolSize, unused2) = pair.getReserves();
      }
      if (poolSize > largestPoolSize) {
        largestPoolSize = poolSize;
        largestKeyToken = tokenList[i];
        largestPoolAddress = pairAddress;
      }
    }
    if (largestPoolSize < 10**decimals) {
      return (address(0), 0);
    }
    return (largestKeyToken, largestPoolSize);
  }

  //Generic function giving the price of a given token vs another given token on Uniswap.
  function getPriceVsTokenUni(address token0, address token1) public view returns (uint256) {
    address pairAddress = uniswapFactory.getPair(token0,token1);
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    (uint256 reserve0, uint256 reserve1, uint32 unused) = pair.getReserves();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();
    uint256 price;
    if (token0 == pair.token0()) {
      price = (reserve1*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve0;
    } else {
      price = (reserve0*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve1;
    }
    return price;
  }

  //Generic function giving the price of a given token vs another given token on Sushiswap.
  function getPriceVsTokenSushi(address token0, address token1) public view returns (uint256) {
    address pairAddress = sushiswapFactory.getPair(token0,token1);
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    (uint256 reserve0, uint256 reserve1, uint32 unused) = pair.getReserves();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();
    uint256 price;
    if (token0 == pair.token0()) {
      price = (reserve1*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve0;
    } else {
      price = (reserve0*10**(token0Decimals-token1Decimals+precisionDecimals))/reserve1;
    }
    return price;
  }

  //Gives the price of a given keyToken.
  function getKeyTokenPrice(address token) public view returns (uint256) {
    bool isPricingToken = checkPricingToken(token);
    uint256 price;
    uint256 priceVsPricingToken;
    if (token == definedOutputToken) {
      price = 10**precisionDecimals;
    } else if (isPricingToken) {
      price = getPriceVsTokenUni(token,definedOutputToken);
    } else {
      uint256 pricingTokenPrice;
      (address pricingToken, address pricingPool, bool uni, bool sushi) = getLargestPool(token,pricingTokens);
      if (uni) {
        priceVsPricingToken = getPriceVsTokenUni(token,pricingToken);
      } else if (sushi) {
        priceVsPricingToken = getPriceVsTokenSushi(token,pricingToken);
      }
      if (pricingToken == definedOutputToken) {
        pricingTokenPrice = 10**precisionDecimals;
      } else {
        pricingTokenPrice = getPriceVsTokenUni(pricingToken,definedOutputToken);
      }
      price = priceVsPricingToken*pricingTokenPrice/10**precisionDecimals;
    }
    return price;
  }

  //Checks if a given token is in the pricingTokens list.
  function checkPricingToken(address token) public view returns (bool) {
    uint256 i;
    for (i=0;i<pricingTokens.length;i++) {
      if (token == pricingTokens[i]) {
        return true;
      }
    }
    return false;
  }

  //Checks if a given token is in the keyTokens list.
  function checkKeyToken(address token) public view returns (bool) {
    uint256 i;
    for (i=0;i<keyTokens.length;i++) {
      if (token == keyTokens[i]) {
        return true;
      }
    }
    return false;
  }

  function getUniLiquidity(address token0, address token1) public view returns (uint256, uint256) {
    address pairAddress = uniswapFactory.getPair(token0, token1);
    IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
    (uint256 reserve0, uint256 reserve1, uint32 unused) = pair.getReserves();
    uint256 token0Decimals = ERC20(token0).decimals();
    uint256 token1Decimals = ERC20(token1).decimals();
    uint256 amount0;
    uint256 amount1;
    if (token0 == pair.token0()) {
      amount0 = reserve0*10**(precisionDecimals-token0Decimals);
      amount1 = reserve1*10**(precisionDecimals-token1Decimals);
    } else {
      amount0 = reserve1*10**(precisionDecimals-token0Decimals);
      amount1 = reserve0*10**(precisionDecimals-token1Decimals);
    }
    return (amount0, amount1);
  }
}