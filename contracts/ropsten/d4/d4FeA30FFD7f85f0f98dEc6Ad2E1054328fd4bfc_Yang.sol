// SPDX-License-Identifier: GPL3

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol";
import "pancakeswap-core/contracts/interfaces/IPancakeFactory.sol";
import "pancakeswap-core/contracts/interfaces/IPancakePair.sol";

contract Master is Context, IERC20, Ownable, Pausable {

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  uint256 private _totalSupply;
  string private _name;
  string private _symbol;

  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;

    _mint(address(this), 10**18 * 100000000000000);
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
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
    return true;
  }
  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowances[_msgSender()][spender];
    require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
    _approve(_msgSender(), spender, currentAllowance - subtractedValue);

    return true;
  }
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }
  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");

    _beforeTokenTransfer(account, address(0), amount);

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    _balances[account] = accountBalance - amount;
    _totalSupply -= amount;

    emit Transfer(account, address(0), amount);
  }
  function _approve(address owner, address spender, uint256 amount) internal virtual {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
  function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
    require(!paused(), "ERC20Pausable: token transfer while paused");
  }

  //----------------------------------------------------------------------------------------------------

  uint256 private feePercentage = 100;
  uint256 private lpHolderAmount = 1;
  uint256 private lpHolderFee = 5000;
  uint256 private burnPercentage = 5000;
  address public burnAddress = address(0x000000000000000000000000000000000000dEaD);
  address public oppositeAddress = address(0);

  address[] public buybackPath;

  IUniswapV2Router02 public routerUni;
  //IUniswapV2Factory public factoryUni;
  IUniswapV2Pair public lpPairUni;
  IUniswapV2Router02 public routerSushi;
  //IUniswapV2Factory public factorySushi;
  IUniswapV2Pair public lpPairSushi;

  mapping (address => bool) private _isExcluded;

  event Buyback(uint256 inputAmount, uint256 outputAmount);
  event BuybackFailed(uint256 inputAmount, string msg);
  event Burn(uint256 amount);
  event OppositeAddressChanged(address _address);
  event FeePercentageChanged(uint256 newPercentage);
  event LPHolderAmountChanged(uint256 newPercentage);
  event LPHolderFeeChanged(uint256 newPercentage);
  event BurnPercentageChanged(uint256 newPercentage);

  /**
  * @dev Sets the value for {lpHolderAmount}
  */
  function setLPHolderAmount(uint256 _lpHolderAmount) public onlyOwner {
    require(msg.sender == owner(), "setLPHolderAmount: FORBIDDEN");
    require(_lpHolderAmount > 0, "setLPHolderAmount: lpHolderAmount can't be 0");
    lpHolderAmount = _lpHolderAmount;
    emit LPHolderAmountChanged(lpHolderAmount);
  }

  /**
  * @dev Sets the value for {lpHolderFee}
  */
  function setLPHolderFee(uint256 _lpHolderFee) public onlyOwner {
    require(msg.sender == owner(), "setLPHolderFee: FORBIDDEN");
    require(_lpHolderFee < 10000, "setLPHolderFee: fee can't be >=100%");
    require(_lpHolderFee > 0, "setLPHolderFee: fee can't be 0%");
    lpHolderFee = _lpHolderFee;
    emit LPHolderFeeChanged(lpHolderFee);
  }

  /**
  * @dev Sets the value for {feePercentage}
  */
  function setFeePercentage(uint256 _feePercentage) public onlyOwner {
    require(msg.sender == owner(), "setFeePercentage: FORBIDDEN");
    require(_feePercentage < 10000, "setFeePercentage: fee can't be >=100%");
    require(_feePercentage > 0, "setFeePercentage: fee can't be 0%");
    feePercentage = _feePercentage;
    emit FeePercentageChanged(feePercentage);
  }

  /**
  * @dev Sets the value for {burnPercentage}
  */
  function setBurnPercentage(uint256 _burnPercentage) public onlyOwner {
    require(msg.sender == owner(), "setBurnPercentage: FORBIDDEN");
    require(_burnPercentage <= 10000, "setBurnPercentage: burnPercentage can't be >100%");
    burnPercentage = _burnPercentage;
    emit BurnPercentageChanged(burnPercentage);
  }

  /**
  * @dev Sets the value for {oppositeAddress}
  */
  function setOppositeAddress(address _address) public onlyOwner {
    require(msg.sender == owner(), "setOppositeAddress: FORBIDDEN");
    require(_address != address(0), "setOppositeAddress: address can't be the zero address");
    oppositeAddress = _address;
    buybackPath = [address(this), routerUni.WETH(), oppositeAddress];
    emit OppositeAddressChanged(oppositeAddress);
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

  function init() public onlyOwner {
    routerUni = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    lpPairUni = IUniswapV2Pair(IUniswapV2Factory(routerUni.factory()).createPair(address(this), routerUni.WETH()));
    _approve(address(this), address(routerUni), _totalSupply / 2);

    routerSushi = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    lpPairSushi = IUniswapV2Pair(IUniswapV2Factory(routerSushi.factory()).createPair(address(this), routerSushi.WETH()));
    _approve(address(this), address(routerSushi), _totalSupply / 2);
  }

  function addLiquidity() public payable onlyOwner {
    routerUni.addLiquidityETH{value: msg.value / 2}(address(this), _totalSupply / 2, _totalSupply / 2, msg.value / 2, burnAddress, block.timestamp + 1200);
    routerSushi.addLiquidityETH{value: msg.value / 2}(address(this), _totalSupply / 2, _totalSupply / 2, msg.value / 2, burnAddress, block.timestamp + 1200);
  }

  function _transfer(address sender, address recipient, uint256 amount) internal virtual {
    require(sender != address(0), "_transfer: transfer from the zero address");
    require(recipient != address(0), "_transfer: transfer to the zero address");
    require(amount > 0, "_transfer: transfer amount must be greater than zero");
    require(_balances[sender] >= amount, "_transfer: transfer amount exceeds balance");

    if (feePercentage == 0 ||
        sender == address(this) ||
          _isExcluded[sender] ||
            recipient == address(0) ||
              sender == address(routerUni) ||
                recipient == address(routerUni) ||
                  sender == address(lpPairUni) ||
                    recipient == address(lpPairUni) ||
                      sender == address(routerSushi) ||
                        recipient == address(routerSushi) ||
                          sender == address(lpPairSushi) ||
                            recipient == address(lpPairSushi)
       ) {
         _transferExcluded(sender, recipient, amount);
         if (recipient == burnAddress) {
           emit Burn(amount);
         }
       } else if (lpPairUni.balanceOf(sender) >= lpHolderAmount || lpPairSushi.balanceOf(sender) >= lpHolderAmount) {
         _transferStandard(sender, recipient, amount, feePercentage * lpHolderFee / 10000);
       } else {
         _transferStandard(sender, recipient, amount, feePercentage);
       }
  }

  function _transferStandard(address sender, address recipient, uint256 amount, uint256 _fee) private {
    require(sender != address(0), "_transferStandard: transfer from the zero address");
    uint256 fee = amount * _fee / 10000;
    uint256 burn = fee * burnPercentage / 10000;
    uint256 buyback = fee - burn;
    _transferExcluded(sender, recipient, amount - fee);
    _transferExcluded(sender, burnAddress, burn);
    emit Burn(burn);
    if (buyback > 0) {
      uint256 leftOver = _triggerBuyback(sender, buyback);
      if (leftOver > 0) {
        _transferExcluded(address(this), burnAddress, leftOver);
        emit Burn(burn);
      }
    }
  }

  function _transferExcluded(address sender, address recipient, uint256 amount) private {
    require(sender != address(0), "_transferExcluded: transfer from the zero address");
    _beforeTokenTransfer(sender, recipient, amount);

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "_transferExcluded: transfer amount exceeds balance");
    _balances[sender] = senderBalance - amount;
    _balances[recipient] += amount;

    emit Transfer(sender, recipient, amount);
  }

  function _triggerBuyback(address sender, uint256 amount) private returns (uint256) {
    if (oppositeAddress == address(0)) {
      emit BuybackFailed(amount, "ADDRESS_ERROR");
      return amount;
    }

    _transferExcluded(sender, address(this), amount);
    return _buyback(amount);
  }

  function _buyback(uint256 amount) private returns (uint256) {
    bool uni = _buybackRouter(routerUni, amount / 2);
    bool sushi = _buybackRouter(routerSushi, amount / 2);

    if (!uni && sushi) {
      if (!_buybackRouter(routerSushi, amount / 2)) {
        return amount / 2;
      } else {
        return 0;
      }
    } else if (!sushi && uni) {
      if (!_buybackRouter(routerUni, amount / 2)) {
        return amount / 2;
      } else {
        return 0;
      }
    } else if (!uni && !sushi) {
      return amount;
    }
    return 0;
  }

  function _buybackRouter(IUniswapV2Router02 router, uint256 amount) private returns (bool) {
    require(_balances[address(this)] >= amount, "_buybackRouter: buyback amount exceeds balance");
    _approve(address(this), address(routerUni), amount);
    try router.swapExactTokensForTokens(amount, 1, buybackPath, burnAddress, block.timestamp + 1200) returns (uint[] memory amounts) {
      emit Buyback(amount, amounts[amounts.length - 1]);
      return true;
    } catch Error(string memory error) {
      emit BuybackFailed(amount, error);
      return false;
    } catch {
      emit BuybackFailed(amount, "ROUTER_ERROR");
      return false;
    }
  }

  function burned() public view returns (uint256 amount) {
    return _balances[burnAddress];
  }
}