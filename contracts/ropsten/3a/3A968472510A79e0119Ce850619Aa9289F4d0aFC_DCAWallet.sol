// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';


interface ErcToken {
      function transfer(address dst, uint wad) external returns (bool);
      function transferFrom(address src, address dst, uint wad) external returns (bool);
      function balanceOf(address guy) external view returns (uint);
}


contract DCAWallet {
  
  enum TokenType{ USDC, WETH, WBTC}

  // Ropsten addresses
  address[] public token_addresses = [0x68ec573C119826db2eaEA1Efbfc2970cDaC869c4,  //USDC
                                0xc778417E063141139Fce010982780140Aa0cD5Ab,  //WETH
                                0xc3778758D19A654fA6d0bb3593Cf26916fB3d114];  //WBTC


  mapping(address => mapping(uint => uint)) tokenBalances; //owner address => tokenType enum => tokenbalance
  mapping(address => uint[]) portfolioAllocation;  // investment strategy for each owner
  mapping(address => uint) userTimelock;   //timelock where user can't withdraw tokens 


  ISwapRouter public immutable swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    


  uint24 public constant poolFee = 3000;
  
  ErcToken public usdcToken;
  ErcToken public wethToken;
  ErcToken public wbtcToken;

  constructor() {
     
    usdcToken = ErcToken(token_addresses[0]);  
    wethToken = ErcToken(token_addresses[1]);  
    wbtcToken = ErcToken(token_addresses[2]);  
  }



  //User sets up/modifies portfolio allocation
  function createPortfolioAllocation(uint[] memory _portfolio_allocation) public{
    require(_portfolio_allocation.length == 3); // number of tokens under TokenType enum

    uint i;
    uint sum = 0;

    for(i = 0; i<_portfolio_allocation.length; i++ ){
      sum += _portfolio_allocation[i];
    }

    require(sum == 100);

    portfolioAllocation[msg.sender] = _portfolio_allocation;

  }

  

  //Handle deposits of USDC
  function usdcDeposited(uint _amount) public {
    require(_amount > 0, "amount should be greater than 0");

    // Need owner to approve token transfer via javascript UI first
    usdcToken.transferFrom(msg.sender, address(this), _amount);

    tokenBalances[msg.sender][uint(TokenType.USDC)] += _amount;

    executePortfolioBuys(_amount);
  }

  function executePortfolioBuys(uint _amount) internal {
    uint i;
    
    for(i = 1; i<portfolioAllocation[msg.sender].length; i++ ){
      swapExactInputSingle( portfolioAllocation[msg.sender][i] * _amount / 100, i);
    }



  }

  function swapExactInputSingle(uint256 amountIn, uint token_index) internal returns (uint256 amountOut) {
        // msg.sender must approve this contract

        //Deduct USDC balance from sender
        tokenBalances[msg.sender][uint(TokenType.USDC)] -= amountIn;

        // Approve the router to spend USDC.
        TransferHelper.safeApprove(token_addresses[0], address(swapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: token_addresses[0],
                tokenOut: token_addresses[token_index],
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);

        //Add swapped token to senders balance
        tokenBalances[msg.sender][token_index] += amountOut;
    }

  // User can set timelock to prevent any withdrawals/forced to hodl
  function setTimelock(uint _unlockDate) public {
      userTimelock[msg.sender] = _unlockDate;
  }


  //Withdraw/spend tokens from maturing vault
  function withdrawTokens(uint amount, uint token_index) public {
    require(block.timestamp >= userTimelock[msg.sender]);
    require(tokenBalances[msg.sender][token_index] >= amount);

    tokenBalances[msg.sender][token_index] -= amount;
    ErcToken withdrawal_token = ErcToken(token_addresses[token_index]);
    withdrawal_token.transfer(msg.sender, amount);
  }


}