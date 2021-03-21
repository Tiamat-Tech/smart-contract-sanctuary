// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
//import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol";
//import "@BakeryProject/bakery-swap-periphery/contracts/interfaces/IBakerySwapRouter.sol";
//import "@BakeryProject/bakery-swap-core/contracts/interfaces/IBakerySwapFactory.sol";

contract ERC20Fee is Context, IERC20, Ownable {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  uint256 private _totalSupply;
  string private _name;
  string private _symbol;

  constructor(string memory name, string memory symbol) public {
    _name = name;
    _symbol = symbol;
    _mint(_msgSender(), 100000000000000000000000000000000);
  }
  function name() public view virtual returns (string memory) {
    return _name;
  }
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }
  function decimals() public view virtual returns (uint8) {
    return 18;
  }
  function totalSupply() public view virtual override returns (uint256) {
    return _totalSupply;
  }
  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }
  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowances[owner][spender];
  }
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }
  function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);

    uint256 currentAllowance = _allowances[sender][_msgSender()];
    require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
    _approve(sender, _msgSender(), currentAllowance - amount);

    return true;
  }
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowances[_msgSender()][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    _approve(_msgSender(), spender, currentAllowance.sub(subtractedValue));

    return true;
  }
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }
  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    _balances[account] = accountBalance.sub(amount);
    _totalSupply = _totalSupply.sub(amount);

    emit Transfer(account, address(0), amount);
  }
  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

  //----------------------------------------------------------------------------------------------------

  uint256 public feePercentage = 1;
  uint256 public burnPercentage = 50;
  address public burnAddress = address(0x000000000000000000000000000000000000dEaD);
  address public routerAddress = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  address public factoryAddress = address(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
  address public lpAddress = address(0);
  address public wethAddress = address(0);
  address public oppositeAddress = address(0);
  address[] public buybackPath;

  mapping (address => bool) private _isExcluded;

  event Buyback(address buybackToken, uint256 inputAmount);
  event BuybackFailed(address buybackToken, uint256 inputAmount);
  event Burn(uint256 amount);
  event BurnAddressChanged(address _address);
  event RouterAddressChanged(address _address);
  event WETHAddressChanged(address _address);
  event FactoryAddressChanged(address _address);
  event LPAddressChanged(address _address);
  event OppositeAddressChanged(address _address);
  event FeePercentageChanged(uint256 newPercentage);
  event BurnPercentageChanged(uint256 newPercentage);

  /**
   * @dev Sets the value for {feePercentage}
   */
  function setFeePercentage(uint256 _feePercentage) public onlyOwner {
    require(msg.sender == owner(), "setFeePercentage: FORBIDDEN");
    require(_feePercentage < 100, "setFeePercentage: fee can't be >=100%");
    feePercentage = _feePercentage;
    emit FeePercentageChanged(feePercentage);
  }

  /**
   * @dev Sets the value for {burnPercentage}
   */
  function setBurnPercentage(uint256 _burnPercentage) public onlyOwner {
    require(msg.sender == owner(), "setBurnPercentage: FORBIDDEN");
    require(_burnPercentage <= 100, "setBurnPercentage: burn can't be >100%");
    burnPercentage = _burnPercentage;
    emit BurnPercentageChanged(burnPercentage);
  }

  /**
   * @dev Sets the value for {burnAddress}
   */
  function setBurnAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setBurnAddress: FORBIDDEN");
    require(_address != address(0), "setBurnAddress: address can't be the zero address");
    burnAddress = _address;
    emit BurnAddressChanged(burnAddress);
  }

  /**
   * @dev Sets the value for {routerAddress}
   */
  function setRouterAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setRouterAddress: FORBIDDEN");
    require(_address != address(0), "setRouterAddress: address can't be the zero address");
    routerAddress = _address;
    buybackPath = [address(this), wethAddress, oppositeAddress];
    emit RouterAddressChanged(routerAddress);
  }

  /**
   * @dev Sets the value for {wethAddress}
   */
  function setWETHAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setWETHAddress: FORBIDDEN");
    require(_address != address(0), "setWETHAddress: address can't be the zero address");
    wethAddress = _address;
    buybackPath = [address(this), wethAddress, oppositeAddress];
    emit WETHAddressChanged(wethAddress);
  }

  /**
   * @dev Sets the value for {oppositeAddress}
   */
  function setOppositeAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setOppositeAddress: FORBIDDEN");
    require(_address != address(0), "setOppositeAddress: address can't be the zero address");
    oppositeAddress = _address;
    buybackPath = [address(this), wethAddress, oppositeAddress];
    emit OppositeAddressChanged(oppositeAddress);
  }

  /**
   * @dev Sets the value for {factoryAddress}
   */
  function setFactoryAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setOppositeAddress: FORBIDDEN");
    require(_address != address(0), "setOppositeAddress: address can't be the zero address");
    factoryAddress = _address;
    emit FactoryAddressChanged(factoryAddress);
  }

  /**
   * @dev Sets the value for {lpAddress}
   */
  function setLPAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setOppositeAddress: FORBIDDEN");
    require(_address != address(0), "setOppositeAddress: address can't be the zero address");
    lpAddress = _address;
    emit LPAddressChanged(lpAddress);
  }

  function _getPair() private returns (address) {
    require(wethAddress == address(0), "getPair: wethAddress can't be the zero address");
    require(factoryAddress == address(0), "getPair: factoryAddress can't be the zero address");
    IUniswapV2Factory factory = IUniswapV2Factory(factoryAddress);
    return factory.getPair(address(this), wethAddress);
  }

  function isExcluded(address account) public view returns (bool) {
    return _isExcluded[account];
  }

  function excludeAccount(address _address) external onlyOwner {
    require(msg.sender == owner(), "excludeAccount: FORBIDDEN");
    require(!_isExcluded[_address], "excludeAccount: account is already excluded");
    _isExcluded[_address] = true;
  }

  function includeAccount(address _address) external onlyOwner {
    require(msg.sender == owner(), "includeAccount: FORBIDDEN");
    require(_isExcluded[_address], "includeAccount: account is not excluded");
    _isExcluded[_address] = false;
  }

  /*function triggerBuyback(uint256 amount) public onlyOwner {
    require(msg.sender == owner(), "triggerBuyback: FORBIDDEN");
    require(oppositeAddress == address(0), "triggerBuyback: oppositeAddress can't be the zero address")
    require(wethAddress == address(0), "triggerBuyback: wethAddress can't be the zero address")
    require(routerAddress == address(0), "triggerBuyback: routerAddress can't be the zero address")
    require(factoryAddress == address(0), "triggerBuyback: factoryAddress can't be the zero address")
    require(lpAddress == address(0), "triggerBuyback: lpAddress can't be the zero address")
    require(_buyback(amount), "triggerBuyback: buyback failed");
  }


  function triggerBuyback() public onlyOwner {
    triggerBuyback(_balances[address(this)]);
  }*/

  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "_transfer: transfer from the zero address");
    require(recipient != address(0), "_transfer: transfer to the zero address");
    require(amount > 0, "_transfer: transfer amount must be greater than zero");
    require(_balances[sender] >= amount, "_transfer: transfer amount exceeds balance");
    if (feePercentage == 0 ||
        _isExcluded[sender] ||
          recipient == burnAddress ||
            sender == routerAddress ||
              recipient == routerAddress ||
                sender == lpAddress ||
                  recipient == lpAddress
       ) {
         _transferExcluded(sender, recipient, amount);
         if (recipient == burnAddress) {
           emit Burn(amount);
         }
       } else {
         _transferStandard(sender, recipient, amount);
       }
  }

  function _transferStandard(address sender, address recipient, uint256 amount) private {
    uint256 fee = amount.mul(feePercentage).div(100);
    uint256 burn = fee.mul(burnPercentage).div(100);
    uint256 buyback = fee.sub(burn, "_transferStandard: fee exeeds amount");
    _transferExcluded(sender, recipient, amount.sub(fee, "_transferStandard: fee exeeds amount"));
    _transferExcluded(sender, burnAddress, burn);
    emit Burn(burn);
    if (buyback > 0 && !_triggerBuyback(sender, buyback)) {
      _transferExcluded(address(this), burnAddress, buyback);
      emit Burn(burn);
    }
  }

  function _transferExcluded(address sender, address recipient, uint256 amount) private {
    _beforeTokenTransfer(sender, recipient, amount);

    _balances[sender] = _balances[sender].sub(amount, "_transferExcluded: transfer amount exceeds balance");
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _triggerBuyback(address sender, uint256 amount) private returns (bool success) {
    if (oppositeAddress == address(0) ||
        wethAddress == address(0) ||
          routerAddress == address(0) ||
            factoryAddress == address(0) ||
              lpAddress == address(0)
       ) {
         emit BuybackFailed(oppositeAddress, amount);
         return false;
       }

       _transferExcluded(sender, address(this), amount);
       return _buyback(amount);
  }

  function _buyback(uint256 amount) private returns (bool success) {
    require(_balances[address(this)] >= amount, "_buyback: buyback amount exceeds balance");
    IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
    try router.swapExactTokensForTokens(amount, 0, buybackPath, burnAddress, block.timestamp + 150) {
      emit Buyback(oppositeAddress, amount);
      return true;
    } catch {
      emit BuybackFailed(oppositeAddress, amount);
      return false;
    }
  }
}