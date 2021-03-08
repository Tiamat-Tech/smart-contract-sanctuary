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
  mapping (address => uint256) internal assetLimits;
  
  // balances; one level deeper to hold the balance of a specific token per an address
  // example: {0xInvestorAddress: {0xTokenAddress => (uint256 balance)}
  mapping (address => mapping (address => balance)) internal balances;
  
  // balance; used to hold a more efficient set of balances per investor address
  // and token address
  struct balance {
    uint ethAmount;
    uint tokAmount;
  }

  // name; is the name of the IndexFund
  string public name;

  uint256 internal constant ETHER_BASE = 1000000000000000000;
  address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address internal constant UNISWAP_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  
  IUniswapV2Router02 private uniswapRouter;
  IUniswapV2Factory  private uniswapFactory;
  
  /* ============ Events ================= */
  event EnterMarket(
    address indexed from_, 
    uint amountDeposited_,
    uint currentBlock_
  );
  
  event ExitMarket(
    address indexed from_, 
    uint amountWithdrawn_,
    uint currentBlock_
  );
  
  event SwapInit(
    address indexed token_,
    uint amountIn_,
    uint[] amounts_
  );
  
  event SwapSuccess(
    address indexed token_, 
    uint etherAmount_, 
    uint[] amounts_
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
    uint256 totalEther = 0;

    for (uint i = 0; i < assetAddresses.length; i++) {
      address tokenAddress = assetAddresses[i];

      uint256 tokenEtherBase = msg.value.mul(assetLimits[tokenAddress]);
      uint256 tokenEtherAmount = tokenEtherBase.div(ETHER_BASE);
    
      // LIVE -----------------------------------------------------------------------
      try uniswapRouter.swapExactETHForTokens{ 
        value: tokenEtherAmount 
      }(
        0, 
        getPathForETHtoTOKEN(tokenAddress), 
        address(this), 
        block.timestamp.add(120)
      ) returns (uint[] memory tokenAmounts) {
          balances[msg.sender][tokenAddress] = balance(
            tokenAmounts[0], 
            tokenAmounts[1]
          );
            
          emit SwapSuccess(tokenAddress, tokenEtherAmount, tokenAmounts);
      } catch Error(string memory _err) {
          emit SwapFailureString(tokenAddress, _err);
          continue;
      } catch (bytes memory _err) {
          emit SwapFailureBytes(tokenAddress, _err);
          continue;
      }
      
      // TEST -----------------------------------------------------------------------
      // balances[msg.sender][tokenAddress] = balance(
      //   tokenEtherAmount, 
      //   12434562745188401
      // );
  
      // Increment the totalEther deposited
      totalEther = totalEther.add(tokenEtherAmount);
    }
  
    // Refund any unused Ether
    // This needs to only refund the Ether difference from msg.value, not the address
    // ******************************************************************************
    (bool success,) = msg.sender.call{ value: msg.value.sub(totalEther) }("");
    require(success, "enterMarket; refund failed");
    
    // Emit the EnterMarket event
    emit EnterMarket(
      msg.sender,
      totalEther,
      block.number
    );
  }
  
  function exitMarket() public {
    // Keep track of the ether accounted for so if failure, the refunded amount is proper
    uint256 totalEther = 0;
    
    for (uint i = 0; i < assetAddresses.length; i++) {
      address tokenAddress = assetAddresses[i];

      // The original token amount, not ether
      uint amountIn = balances[msg.sender][tokenAddress].tokAmount;
      
      address[] memory path = getPathForTOKENtoETH(tokenAddress);
      uint[] memory returnedAmounts = uniswapRouter.getAmountsOut(amountIn, path);
      
      IERC20 token = IERC20(tokenAddress);
      require(token.approve(UNISWAP_ROUTER_ADDRESS, amountIn),
        "must approve the token out"
      );

      emit SwapInit(tokenAddress, amountIn, returnedAmounts);

      try uniswapRouter.swapExactTokensForETH( 
        returnedAmounts[0],
        returnedAmounts[1],
        path, 
        msg.sender, 
        block.timestamp.add(100)
      ) returns (uint[] memory tokenAmounts) {
        totalEther = totalEther.add(tokenAmounts[1]);
        
        // Remove the record entry for this balance, very important
        delete balances[msg.sender][tokenAddress];
        
        emit SwapSuccess(tokenAddress, amountIn, tokenAmounts);
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
      block.number
    );
  }
  
  function custodialWithdraw(address recipient) public {
    require(owner() == msg.sender,
      "owner must be msg.sender"
    );
    
    // we will need to implement a controller multi approval here, not just the owner
    // sender can initiate this method.
    
    // Reduce the token balances
    for (uint i = 0; i < assetAddresses.length; i++) {
      IERC20 t = IERC20(assetAddresses[i]);
      uint256 balanceOfToken = t.balanceOf(address(this));      
      t.transfer(recipient, balanceOfToken);
    }
    
    // Reduce the ether balance
    (bool success,) = msg.sender.call{ value: address(this).balance }("");
    require(success, "custodialWithdraw; withdraw failed");
  }

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
  
  // getInvestorBalanceByToken; returns the investors token balance
  function getInvestorBalanceByToken(address investor, address token) 
    public view returns(balance memory) 
  { 
    return balances[investor][token]; 
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