/**
 *Submitted for verification at Etherscan.io on 2021-07-23
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IUniswapV2Pair {
  function token0() external view returns (address);

  function token1() external view returns (address);

  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );

  function swap(
    uint amount0Out,
    uint amount1Out,
    address to,
    bytes calldata data
  ) external;
}

interface IUniswapV2Factory {
  function getPair(address token0, address token1) external view returns (address);
}

interface IUniswapV2Callee {
    
  function uniswapV2Call(
    address sender,
    uint amount0,
    uint amount1,
    bytes calldata data
  ) external;
  
}

contract TestFlashLoan is IUniswapV2Callee {
    
    // Max amount => 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
    // Uniswap V2 factory
    address private constant FACTORY = 0xc35DADB65012eC5796536bD9864eD8773aBc74C4;
    address public owner;
    
    event Log(string message, uint val);
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier ownerOnly() {
        require(msg.sender == owner);
        _;
    }
    
    function balanceOf(address _token, address _address) external view returns (uint) {
        return IERC20(_token).balanceOf(_address);
    }
    
    function allowance(address _token, address _owner, address _spender) external view returns (uint) {
        return IERC20(_token).allowance(_owner, _spender);
    }
    
    function approveForContract(address _token, address _spender, uint _amount) external ownerOnly {
        IERC20(_token).approve(_spender, _amount);
    }
    
    function transferBack(address _token, uint _amount) external ownerOnly {
        IERC20(_token).approve(address(this), _amount);
        IERC20(_token).transferFrom(address(this), msg.sender, _amount);
    }
    
    function TestFlashSwap(address _tokenA, address _tokenB, uint _amountBorrow) external ownerOnly {
        address _tokenBorrow = _tokenA;
        address pair = IUniswapV2Factory(FACTORY).getPair(_tokenBorrow, _tokenB);
        require(pair != address(0), "!pair");
        
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        uint amount0Out = _tokenBorrow == token0 ? _amountBorrow : 0;
        uint amount1Out = _tokenBorrow == token1 ? _amountBorrow : 0;
        
        // need to pass some data to trigger uniswapV2Call
        bytes memory data = abi.encode(_amountBorrow);
        
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
        
        uint fee = ((_amountBorrow * 3) / 997) + 1;
        IERC20(token0).transfer(pair, _amountBorrow + fee);
    }
    
    // called by pair contract
    function uniswapV2Call(address _sender, uint _amount0, uint _amount1, bytes calldata _data) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(FACTORY).getPair(token0, token1);
        require(msg.sender == pair, "msg sender address != pair address");
        require(_sender == address(this), "sender address != contract address");
        
        (uint amountBorrow) = abi.decode(_data, (uint));
        
        // about 0.3%
        uint fee = ((amountBorrow * 3) / 997) + 1;
        
        // do stuff here
        emit Log("amount0", _amount0);
        emit Log("amount1", _amount1);
        emit Log("amount", amountBorrow);
        emit Log("fee", fee);
        emit Log("amount to repay", amountBorrow + fee);
        
        // IERC20(tokenBorrow).transfer(pair, amountBorrow + fee);
    }
  
}