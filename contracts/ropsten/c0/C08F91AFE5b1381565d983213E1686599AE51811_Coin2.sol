//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./libs/IBEP20.sol";
import "./libs/Safemath.sol";
import "./libs/IUniswapV2Router.sol";
import "./libs/IUniswapV2Factory.sol";

contract Coin2 is IBEP20 {
    using SafeMath for uint256;
   
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;
    uint8 private _decimals;
    address private owner;

  mapping(address => uint256) public _balances;
  mapping(address => mapping(address => uint256)) public _allowances;

  IUniswapV2Router swapRouter;
  address public nativeTokenPair;
  address internal reflectorToken = 0x32541f3C4d5EA7a8b5C07a16E74a2615247c8858;
  address internal WFTM = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
  address internal routerAddress =  0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address DEAD = 0x000000000000000000000000000000000000dEaD;
  address ZERO = 0x0000000000000000000000000000000000000000;
  address DEAD_NON_CHECKSUM = 0x000000000000000000000000000000000000dEaD;

  bool isSwapEnabled = true;
  bool isInSwap;

  uint256 public swapThreshold = _totalSupply/1000;

  uint256 targetLiquidity = 10;
  uint256 targetLiquidityDenominator = 100;

   uint256 liquidityFee = 500;
    uint256 buybackFee = 0;
    uint256 reflectionFee = 500;
    uint256 marketingFee = 200;
    uint256 TCHSavings = 300;
    uint256 totalFee = 1500;
    uint256 feeDenominator = 10000;

     address public autoLiquidityReceiver=0x7Fe040190Cae8dcd6Dc6EB3Aa857e07C5ab09DeB; //liq address
    address public marketingFeeReceiver=0xFF341d69619FAeE2F07C018Ce2B3b8501f31636D; // marketing address


  modifier swapping(){
      isInSwap = true;
      _;
      isInSwap = false;
  }

  constructor() {
     _name = "Coin2";
     _symbol = "CN2";
     _decimals = 6;
     _totalSupply = 100000000 * 10 ** 6;
     owner = msg.sender;
     swapRouter = IUniswapV2Router(routerAddress);
     nativeTokenPair = IUniswapV2Factory(swapRouter.factory()).createPair(WFTM,address(this));
      _allowances[address(this)][address(swapRouter)] = _totalSupply;
      //approve(routerAddress,_totalSupply);
       //approve(address(nativeTokenPair),_totalSupply);
     //_allowances[msg.sender][routerAddress] = _totalSupply;
     //_allowances[msg.sender][address(nativeTokenPair)] = _totalSupply;
     _balances[msg.sender] = _totalSupply;
  }

  function name()external view override returns(string memory) {
     return _name;
  }

  function symbol()external view override returns(string memory){
     return _symbol;
  }

  function totalSupply()external view override returns(uint256){
      return _totalSupply;
  }

  function decimals()external view override returns(uint8){
      return _decimals;
  }

  function getOwner()external view override returns(address){
      return owner;
  }

  function balanceOf(address _address)public view override returns(uint256){
      return _balances[_address];
  }

  function allowance(address _owner, address _spender)external view override returns(uint256){
      return _allowances[_owner][_spender];
  }

  function approve(address spender_, uint256 amount)public override returns (bool) {
       require(_balances[msg.sender]>=amount,"Insufficient balance");
       _allowances[msg.sender][spender_] = amount;
       return true;
  }

  function transfer(address recipient, uint256 amount)external override returns(bool) {
    return _transfer(msg.sender,recipient,amount);
  }

  function transferFrom(address sender_, address recipient_, uint256 amount)external override returns(bool){
  require(_allowances[sender_][msg.sender]>=amount,"Exceeded allowance");
    return _transfer(sender_,recipient_,amount);
  }

  function _transfer(address sender_, address recipient, uint256 amount)internal returns(bool){

      require(_balances[sender_]>=amount,"Insufficient balance");

      //check if is selling
      bool isSelling = recipient == nativeTokenPair || recipient == routerAddress;

      bool shouldSwap = shouldSwapTokens();
      if(isSelling){
          if(shouldSwap){
            swapBack();
            emit logSwapBack(shouldSwap,isSelling);
          }
      }
      _balances[sender_] = _balances[sender_] - amount;
      _balances[recipient] = _balances[recipient] + amount;
      emit Transfer(recipient,amount);
      return true;
  }

   function shouldSwapTokens() internal view returns (bool) {
        return msg.sender != nativeTokenPair
        && !isInSwap
        && isSwapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

      function swapBack() internal swapping {
        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
        uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(totalFee).div(2);
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WFTM;
        uint256 balanceBefore = address(this).balance;

        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountFTM = address(this).balance.sub(balanceBefore);

        uint256 totalFTMFee = totalFee.sub(dynamicLiquidityFee.div(2));

        uint256 amountFTMLiquidity = amountFTM.mul(dynamicLiquidityFee).div(totalFTMFee).div(2);
        uint256 amountFTMReflection = amountFTM.mul(reflectionFee).div(totalFTMFee);
        uint256 amountFTMMarketing = amountFTM.mul(marketingFee).div(totalFTMFee);

        //try distributor.deposit{value: amountFTMReflection}() {} catch {}
        payable(marketingFeeReceiver).transfer(amountFTMMarketing);
            
        if(amountToLiquify > 0){
            swapRouter.addLiquidityETH{value: amountFTMLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountFTMLiquidity, amountToLiquify);
        }
       emit logSwapBack1(isOverLiquified(targetLiquidity, targetLiquidityDenominator),dynamicLiquidityFee,amountToLiquify,amountToSwap,totalFee);
    }

     function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

      function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(nativeTokenPair).mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }

    event Transfer(address indexed rec, uint256 indexed amount);
    event logSwapBack(bool shouldSwapBack,bool isSelling);
    event logSwapBack1(bool isOverLiquified,uint256 dynamicLiquidityFee, uint256 amountToLiquify,uint256 amountToSwap, uint256 totalFee);
    event AutoLiquify(uint256 amountFTM, uint256 amountBOG);
    event BuybackMultiplierActive(uint256 duration);

}