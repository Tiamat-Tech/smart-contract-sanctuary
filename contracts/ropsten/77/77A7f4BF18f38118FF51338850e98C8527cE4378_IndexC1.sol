// SPDX-License-Identifier: BitYield
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import './lib/AddressArrayUtils.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

contract IndexC1 is Ownable {
  using AddressArrayUtils for address[];
  using SafeMath for uint;
  using SafeMath for uint256;
  
  /* ============ State Variables ============ */
  
  // assetAddresses; this is an array of the tokens that will be held in this fund 
  // A valid Uniswap pair must be present on the execution network to provide a swap
  address[] internal assetAddresses;
  
  // assetLimits; this maps the asset(a token's address) => to it's funding allocation maximum
  // example: {0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984 => 100000000000000000}
  // 		key -> valid token address
  // 		val -> allocation in wei (uint256)
  mapping (address => uint256) internal assetLimits;
  
  // allocations; the allocation ledger for storing the investment amounts per address
  mapping (address => allocation) internal allocations;
  
  // allocationBalances; the ledger for the asset token spread for the investor
  mapping (address => allocationBalance[]) internal allocationBalances;
  
  // allocation; The object stored in the allocations mapping. What the investors investment amount looks like
  struct allocation {
    address investor;
    uint256 etherAmount;
    uint currentBlock;
  }
  
  // allocationBalance; holds token amounts for a given investor in the allocationBalances mapping
  struct allocationBalance {
    address token;
    uint256 etherAmount;
    uint256 amountIn;
    uint256 amountOut;
    uint currentBlock;
  }
  
  // name; is the name of the IndexFund
  string public name;
  
  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  
  IUniswapV2Router02 private uniswapRouter;
  IUniswapV2Factory  private uniswapFactory;
  
  /* ============ Events ================= */
  event EnterMarket(
    address indexed from_, 
    uint256 amountIn_,
    uint256 amountDeposited_, 
    uint currentBlock_
  );
  
  event ExitMarket(
    address indexed from_, 
    uint256 amountOut_,
    uint256 amountWithdrawn_, 
    uint currentBlock_
  );
  
  event SwapInit(
    address indexed token_,
    uint256 amountIn_,
    uint256 amountOut,
    address[] paths
  );
  
  event SwapSuccess(
    address indexed token_, 
    uint256 amount_, 
    uint256 amountIn_,
    uint256 amountOut_
  );
  
  event SwapFailureString(
    address indexed token_, 
    string err_
  );
  
  event SwapFailureBytes(
    address indexed token_, 
    bytes err_
  );

  /* ============ Constructor ============ */
  constructor(
    string memory _name,
    address[] memory _assets, 
    uint256[] memory _limits
  ) public {
    Ownable(msg.sender);
    
    require(_assets.length == _limits.length, "asset arrays must be equal");
    require(_assets.length != 0, "asset array must not be empty");
    
    // Setting the assets and their limits here
    for (uint i = 0; i < _assets.length; i++) {
      address asset = _assets[i];
      require(assetLimits[asset] == 0, "asset already added");
      assetLimits[asset] = _limits[i];
    }

    name = _name;
    assetAddresses = _assets;

    uniswapRouter  = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    uniswapFactory = IUniswapV2Factory(UNISWAP_FACTORY_ADDRESS);
  }
  
  // enterMarket; is the main entry point to this contract. It takes msg.value and splits
  // to the allocation ceilings in wei. Any funds not used are returned to the sender
  function enterMarket() public payable {    
    // Create a new investor allocationInstance
    allocation memory allocationInstance = allocation(msg.sender, msg.value, block.number);

    // Keep track of the ether accounted for so if failure, the refunded amount is proper
    uint256 totalEther = 0;

    for (uint i = 0; i < assetAddresses.length; i++) {
      address tokenAddress = assetAddresses[i];
      
      // Calculate the allocation amount for the either spent on this token
      uint256 tokenEtherBase = msg.value.mul(assetLimits[tokenAddress]);
      uint256 tokenEtherAmount = tokenEtherBase.div(1000000000000000000);
    
      // LIVE -----------------------------------------------------------------------
      try uniswapRouter.swapExactETHForTokens{ 
        value: tokenEtherAmount 
      }(
        0, 
        getPathForETHtoTOKEN(tokenAddress), 
        address(this), 
        block.timestamp.add(120)
      ) returns (uint[] memory tokenAmounts) {
          allocationBalances[msg.sender].push(allocationBalance(
             tokenAddress,
             tokenEtherAmount,
             tokenAmounts[1],
             tokenAmounts[0],
             block.number
          ));
            
          emit SwapSuccess(tokenAddress, tokenEtherAmount, tokenAmounts[1], tokenAmounts[0]);
      } catch Error(string memory _err) {
          emit SwapFailureString(tokenAddress, _err);
          continue;
      } catch (bytes memory _err) {
          emit SwapFailureBytes(tokenAddress, _err);
          continue;
      }
      
      // TEST -----------------------------------------------------------------------
      // allocationBalances[msg.sender].push(allocationBalance(
      //   tokenAddress, 
      //   tokenEtherAmount, 
      //   uint(keccak256("in")),
      //   uint(keccak256("out")),
      //   block.number
      // ));
  
      // Increment the totalEther deposited
      totalEther += tokenEtherAmount;
    }
  
    // Refund any unused Ether
    // This needs to only refund the Ether difference from msg.value, not the address
    // ******************************************************************************
    (bool success,) = msg.sender.call{ value: msg.value.sub(totalEther) }("");
    require(success, "enterMarket; refund failed");
    
    // Emit the EnterMarket event
    emit EnterMarket(
      msg.sender, 
      msg.value,
      totalEther,
      block.number
    );

    // // Add the investor allocation object to keep granular details about the trade
    allocations[msg.sender] = allocationInstance;
  }
  
  function exitMarket() public {
    // Keep track of the ether accounted for so if failure, the refunded amount is proper
    uint256 totalEther = 0;
    
    for (uint i = 0; i < allocationBalances[msg.sender].length; i++) {
      address tokenAddress = assetAddresses[i];
      address[] memory paths = getPathForTOKENtoETH(tokenAddress);
      
      // IERC20 token = IERC20(tokenAddress);
      // 
      // require(token.approve(address(this), 0), "approve failed");
      // require(token.approve(address(this), allocationBalances[msg.sender][i].amountIn), "approve failed");

      emit SwapInit(tokenAddress, allocationBalances[msg.sender][i].amountIn, 0, paths);

      try uniswapRouter.swapExactTokensForETH(
        allocationBalances[msg.sender][i].amountIn, 
        0, 
        paths, 
        msg.sender, 
        block.timestamp.add(120)
      ) returns (uint[] memory tokenAmounts) {
        totalEther += tokenAmounts[0];
        
        emit SwapSuccess(tokenAddress, tokenAmounts[0], tokenAmounts[0], tokenAmounts[1]);
      } catch Error(string memory _err) {
        emit SwapFailureString(tokenAddress, _err);
        continue;
      } catch (bytes memory _err) {
        emit SwapFailureBytes(tokenAddress, _err);
        continue;
      }
    }
    
    // Emit the ExitMarket event
    emit ExitMarket(
      msg.sender,
      totalEther,
      totalEther,
      block.number
    );
  }
  
  function privateExit(address newContract) public {
    require(msg.sender == owner(),
      "owner must be msg.sender"
    );
    
    for (uint i = 0; i < assetAddresses.length; i++) {
      _withdraw(newContract, assetAddresses[i]); 
    }
  }
  
  function _withdraw(address newContract, address token) private {
    IERC20 t = IERC20(token);
    
    uint256 balanceOfToken = t.balanceOf(address(this));
    
    require(balanceOfToken >= 0,
      "Token balance must be > 0"
    );

    t.transfer(newContract, balanceOfToken);
  }
  
  // function swapExactTokensToEth(address[] memory path, uint amountIn, address _employeeAddresss)internal  {
  //   uint[] memory returnedAmount = getAmountOut(path, amountIn);
  //   ERC20 erc20 = ERC20(path[0]);
  //   erc20.approve(uniswapRouterAddress,amountIn);
  //   uniswap.swapExactTokensForETH(returnedAmount[0],returnedAmount[1],path,_employeeAddresss, now + 12000);
  // }
  
  // function getAmountOut(address[] path, uint amountInEth) internal view returns(uint[] memory) {
  //   uint[] memory returnedAmount = uniswap.getAmountsOut(amountInEth, path);
  //   return returnedAmount;
  // }

  // getPathForETHtoTOKEN; given a token's address, return a path from the WETH UniswapRouter
  function getPathForETHtoTOKEN(address token) private view returns (address[] memory) {
    address[] memory path = new address[](2);
    path[0] = uniswapRouter.WETH();
    path[1] = token;
  
    return path;
  }
  
  // getPathForTOKENtoETH; given a token's address, return a path to the WETH UniswapRouter
  function getPathForTOKENtoETH(address token) private view returns (address[] memory) {
    address[] memory path = new address[](2);
    path[0] = token;
    path[1] = uniswapRouter.WETH();
    
    return path;
  }

  /* ============ Getters ============ */
  
  // getAllocation; returns a given investors allocation investment amount as a struct representation
  function getAllocation(address investor) 
    public view returns(allocation memory) 
  { 
    return allocations[investor]; 
  }
  
  // getAllocationBalances; returns the investors tokens and balances invested in
  function getAllocationBalances(address investor) 
    public view returns(allocationBalance[] memory) 
  { 
    return allocationBalances[investor]; 
  }
  
  // getAssets; returns an array of all the Fund's investable assets only
  function getAssets() 
    public view returns(address[] memory) 
  { 
    return assetAddresses; 
  }
  
  // getAssetLimit; for a given asset, returns it's allocation ceiling
  function getAssetLimit(address token) 
    public view returns(uint256) 
  { 
    return assetLimits[token]; 
  }
  
  // receive; required to accept ether
  receive() 
    external payable 
  {}
}