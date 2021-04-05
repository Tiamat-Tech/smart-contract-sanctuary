//"SPDX-License-Identifier: UNLICENSED"

pragma solidity 0.7.3;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRC3 {
    enum Category { Music, Painting }
    enum TokenState { Pending, ForSale, Sold, Transferred }
    struct Card {
        uint price;
        Category category;
        TokenState state;
    }
    function getPrice(uint _tokenId) external view returns (uint price);
    function buyRC3(uint256 _tokenId) external payable returns(bool);
}

interface UniswapV2Router{
    function WETH() external pure returns (address);
    
    function swapTokensForExactETH(
        uint amountOut, 
        uint amountInMax, 
        address[] calldata path, 
        address to, 
        uint deadline) external returns (uint[] memory amounts);
}

interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

library UniswapV2Library { 

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }


    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            ))));
    }
    

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) - 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

contract RC3Sales is Ownable {
    
    IRC3 private RC3;
    IUniswapV2Factory private _iUniswapV2Factory;
    UniswapV2Router private _uniswapV2Router;
    
    //key value pair of token address to boolean
    mapping (address => bool) public assets;

    event Sent(address indexed payee, uint amount);
    event BoughtWithETH(uint indexed tokenID, uint amount);
    event BoughtWithToken(uint indexed tokenID, uint amount, address tokenAddress);

    constructor(address _RC3Address) { 
       
        require(_RC3Address != address(0) && _RC3Address != address(this), "wrong address inputted");
       
        RC3 = IRC3(_RC3Address);
        _iUniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
        _uniswapV2Router = UniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);        
    }
    
    function buyWithSupportedToken(address _payWith, uint _tokenId, uint _deadline) external returns(bool) {
        
        require(assets[_payWith], "asset not supported");
        
        uint _amountETH = RC3.getPrice(_tokenId);
        uint _amountToken = priceOracle(_amountETH, _uniswapV2Router.WETH(), _payWith);
        require(IERC20(_payWith).transferFrom(msg.sender, address(this), _amountToken), "need to approve contract");
        
        _convertToETH(_amountETH, _amountToken, _payWith, _deadline);
        RC3.buyRC3{value: _amountETH}(_tokenId);
        
        emit BoughtWithToken(_tokenId, _amountToken, _payWith);
        return true;
    }
    
    function _convertToETH(uint _amountETH, uint _amountToken, address _token, uint _deadline) private {
        
        _uniswapV2Router.swapTokensForExactETH(
            _amountETH, _amountToken, _getPathForTokenToETH(_token), address(this), block.timestamp + _deadline);
    }
    
    function _getPathForTokenToETH(address _token) private view returns(address[] memory) {
        address[] memory path = new address[](2);
        path[0] = _token;
        path[1] = _uniswapV2Router.WETH();
        
        return path;
    }
    
    function withdrawETH(address payable _to, uint256 _amount) external onlyOwner returns(bool) {
        
        require(_to != address(0) && _to != address(this), "wrong address inputted");
        require(_amount > 0 && _amount <= address(this).balance, "invalid amount inputted");
        
        _to.transfer(_amount);
        
        emit Sent(_to, _amount);
        return true;
    }
    
    function addSupportedToken(address _address) external onlyOwner returns(bool) {
        
        require(!assets[_address], "asset already added");
        assets[_address] = true;
        return true;
    }
    
    function priceOracle(uint _amount, address _tokenA, address _tokenB) public view returns(uint tokenBAmount) {
        
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(address(_iUniswapV2Factory), _tokenA, _tokenB);
        return UniswapV2Library.quote(_amount, reserveA, reserveB);
    }
}