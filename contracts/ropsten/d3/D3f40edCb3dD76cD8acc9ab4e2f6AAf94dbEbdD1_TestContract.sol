// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract TestContract is Context, IERC20, Ownable {
  using SafeMath for uint256;
  using Address for address;

  mapping(address => uint256) private _rOwned;
  mapping(address => uint256) private _tOwned;
  mapping(address => mapping(address => uint256)) private _allowances;

  mapping(address => bool) private _isExcludedFromFee;

  mapping(address => bool) private _isExcluded;
  address[] private _excluded;

  uint256 private constant MAX = ~uint256(0);
  uint256 private _tTotal = 10000000000 * 10**9;
  uint256 private _rTotal = (MAX - (MAX % _tTotal));
  uint256 private _tFeeTotal;

  string private _name = 'Test Capital';
  string private _symbol = 'TEST';
  uint8 private _decimals = 9;

  uint256 private _buyLiquidityTax = 5;
  uint256 private _buyReflectionTax = 5;
  uint256 private _sellLiquidityTax = 7;
  uint256 private _sellTreasuryTax = 7;
  uint256 private _sellDividendTax = 6;

  uint256 private _pbuyLiquidityTax = _buyLiquidityTax;
  uint256 private _pbuyReflectionTax = _buyReflectionTax;
  uint256 private _psellLiquidityTax = _sellLiquidityTax;
  uint256 private _psellTreasuryTax = _sellTreasuryTax;
  uint256 private _psellDividendTax = _sellDividendTax;

  uint256 private _dividendBalance = 0;

  address payable public _treasuryWallet;

  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;
  mapping(address => bool) private _isUniswapPair;

  bool inSwap = false;
  bool public swapEnabled = true;

  uint256 private _maxTxAmount = 300000000000000e9;
  uint256 private _maxWalletAmount = 100000000000000e9;
  // We will set a minimum amount of tokens to be swaped => 5M
  uint256 private _numOfTokensToExchangeForTeam = 5 * 10**3 * 10**9;

  DividendTracker public dividendTracker;
  event SendDividends(uint256 tokensSwapped, uint256 amount);

  event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
  event SwapEnabledUpdated(bool enabled);

  modifier lockTheSwap() {
    inSwap = true;
    _;
    inSwap = false;
  }

  constructor() {
    _treasuryWallet = payable(0xAF3d50bD0AB1AFCAEd296540b8FC123FE9CA49EF);
    _rOwned[_msgSender()] = _rTotal;

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    ); // UniswapV2 for Ethereum network
    // Create a uniswap pair for this new token
    uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
      address(this),
      _uniswapV2Router.WETH()
    );
    approve(address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D), MAX);

    // set the rest of the contract variables
    uniswapV2Router = _uniswapV2Router;

    dividendTracker = new DividendTracker(address(this), address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D));

    dividendTracker.excludeFromDividends(address(dividendTracker), true);
    dividendTracker.excludeFromDividends(address(this), true);
    dividendTracker.excludeFromDividends(owner(), true);
    dividendTracker.excludeFromDividends(address(_uniswapV2Router), true);

    // Exclude owner and this contract from fee
    _isExcludedFromFee[owner()] = true;
    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[address(dividendTracker)] = true;

    emit Transfer(address(0), _msgSender(), _tTotal);
  }

  function name() public view returns (string memory) { return _name; }
  function symbol() public view returns (string memory) { return _symbol; }
  function decimals() public view returns (uint8) { return _decimals; }
  function totalSupply() public view override returns (uint256) { return _tTotal; }

  function balanceOf(address account) public view override returns (uint256) {
    if (_isExcluded[account]) return _tOwned[account];
    return tokenFromReflection(_rOwned[account]);
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(
      sender,
      _msgSender(),
      _allowances[sender][_msgSender()].sub(
        amount,
        'ERC20: transfer amount exceeds allowance'
      )
    );
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender].add(addedValue)
    );
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender].sub(
        subtractedValue,
        'ERC20: decreased allowance below zero'
      )
    );
    return true;
  }

  function isExcluded(address account) public view returns (bool) {
    return _isExcluded[account];
  }

  function setExcludeFromFee(address account, bool excluded)
    external
    onlyOwner
  {
    _isExcludedFromFee[account] = excluded;
  }

  function totalFees() public view returns (uint256) {
    return _tFeeTotal;
  }

  function deliver(uint256 tAmount) public {
    address sender = _msgSender();
    require(
      !_isExcluded[sender],
      'Excluded addresses cannot call this function'
    );
    (uint256 rAmount, , , , , ,) = _getValues(tAmount, false);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rTotal = _rTotal.sub(rAmount);
    _tFeeTotal = _tFeeTotal.add(tAmount);
  }

  function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
    public
    view
    returns (uint256)
  {
    require(tAmount <= _tTotal, 'Amount must be less than supply');
    if (!deductTransferFee) {
      (uint256 rAmount, , , , , ,) = _getValues(tAmount, false);
      return rAmount;
    } else {
      (, uint256 rTransferAmount, , , , ,) = _getValues(tAmount, false);
      return rTransferAmount;
    }
  }

  function tokenFromReflection(uint256 rAmount) public view returns (uint256) {
    require(rAmount <= _rTotal, 'Amount must be less than total reflections');
    uint256 currentRate = _getRate();
    return rAmount.div(currentRate);
  }

  function excludeAccount(address account) external onlyOwner {
    require(
      account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D,
      'We can not exclude Uniswap router.'
    );
    require(!_isExcluded[account], 'Account is already excluded');
    if (_rOwned[account] > 0) {
      _tOwned[account] = tokenFromReflection(_rOwned[account]);
    }
    _isExcluded[account] = true;
    _excluded.push(account);
  }

  function includeAccount(address account) external onlyOwner {
    require(_isExcluded[account], 'Account is already excluded');
    for (uint256 i = 0; i < _excluded.length; i++) {
      if (_excluded[i] == account) {
        _excluded[i] = _excluded[_excluded.length - 1];
        _tOwned[account] = 0;
        _isExcluded[account] = false;
        _excluded.pop();
        break;
      }
    }
  }

 function removeAllFee() private {
    if (_buyLiquidityTax == 0 && _sellLiquidityTax == 0) return;

    _pbuyLiquidityTax = _buyLiquidityTax;
    _pbuyReflectionTax = _buyReflectionTax;
    _psellLiquidityTax = _sellLiquidityTax;
    _psellTreasuryTax = _sellTreasuryTax;
    _psellDividendTax = _sellDividendTax;

    _buyLiquidityTax = 0;
    _buyReflectionTax = 0;
    _sellLiquidityTax = 0;
    _sellTreasuryTax = 0;
    _sellDividendTax = 0;
  }

  function restoreAllFee() private {
    _buyLiquidityTax = _pbuyLiquidityTax;
    _buyReflectionTax = _pbuyReflectionTax;
    _sellLiquidityTax = _psellLiquidityTax;
    _sellTreasuryTax = _psellTreasuryTax;
    _sellDividendTax = _psellDividendTax;
  }

  function isExcludedFromFee(address account) public view returns (bool) {
    return _isExcludedFromFee[account];
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) private {
    require(owner != address(0), 'ERC20: approve from the zero address');
    require(spender != address(0), 'ERC20: approve to the zero address');

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) private {
    require(sender != address(0), 'ERC20: transfer from the zero address');
    require(recipient != address(0), 'ERC20: transfer to the zero address');
    require(amount > 0, 'Transfer amount must be greater than zero');

    if (sender != owner() && recipient != owner())
      require(
        amount <= _maxTxAmount,
        'Transfer amount exceeds the maxTxAmount.'
      );

    // is the token balance of this contract address over the min number of
    // tokens that we need to initiate a swap?
    // also, don't get caught in a circular team event.
    // also, don't swap if sender is uniswap pair.
    uint256 contractTokenBalance = balanceOf(address(this));

    if (contractTokenBalance >= _maxTxAmount) {
      contractTokenBalance = _maxTxAmount;
    }

    bool overMinTokenBalance = contractTokenBalance >=
      _numOfTokensToExchangeForTeam;
    if (
      !inSwap &&
      swapEnabled &&
      overMinTokenBalance &&
      (recipient == uniswapV2Pair || _isUniswapPair[recipient])
    ) {
      // We need to swap the current tokens to ETH and send to the team wallet
      swapTokensForEth(contractTokenBalance);

      uint256 contractETHBalance = address(this).balance;
      if (contractETHBalance > 0) {
        if (contractETHBalance > _dividendBalance) {
          address(dividendTracker).call{value: _dividendBalance}('');
        }
        sendETHToTeam(contractETHBalance - _dividendBalance);
      }
    }

    // indicates if fee should be deducted from transfer
    bool takeFee = false;

    // take fee only on swaps
    if (
      (sender == uniswapV2Pair ||
        recipient == uniswapV2Pair ||
        _isUniswapPair[recipient] ||
        _isUniswapPair[sender]) &&
      !(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient])
    ) {
      takeFee = true;
    }

    //transfer amount, it will take tax and team fee
    _tokenTransfer(sender, recipient, amount, takeFee);
  }

  function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), tokenAmount);

    // make the swap
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function sendETHToTeam(uint256 amount) private {
    _treasuryWallet.call{ value: amount }('');
  }


  function _tokenTransfer(
    address sender,
    address recipient,
    uint256 amount,
    bool takeFee
  ) private {
    if (!takeFee) removeAllFee();

    bool isSelling = _isSelling(recipient);
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rFee,
      uint256 tTransferAmount,
      uint256 tFee,
      uint256 tTeamFee,
      uint256 dividend
    ) = _getValues(amount, isSelling);

    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

    if (_isExcluded[sender]) {
      _tOwned[sender] = _tOwned[sender].sub(amount);
    }
    if (_isExcluded[recipient]) {
      _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
    }

    if (!isSelling) {
      _reflectFee(rFee, tFee);
      _distributeTax(tTeamFee, 0);
    } else {
      _distributeTax(tTeamFee, dividend);
    }
    if (!takeFee) restoreAllFee();

    dividendTracker.setBalance(payable(sender), balanceOf(sender));
    dividendTracker.setBalance(payable(recipient), balanceOf(recipient));
    emit Transfer(sender, recipient, tTransferAmount);
  }

  function _distributeTax(
    uint256 tTeam,
    uint256 dividend
  ) private {
    uint256 currentRate = _getRate();
    uint256 rTeam = tTeam.mul(currentRate);
    _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    if (_isExcluded[address(this)]) {
      _tOwned[address(this)] = _tOwned[address(this)].add(tTeam);
    }
    // dividend here
    if (dividend > 0) {
      _dividendBalance += dividend;
    }
  }

  function _reflectFee(uint256 rFee, uint256 tFee) private {
    _rTotal = _rTotal.sub(rFee);
    _tFeeTotal = _tFeeTotal.add(tFee);
  }

  //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}

  function _getValues(uint256 tAmount, bool isSelling)
    private
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    uint256 currentRate = _getRate();
    if (!isSelling) {
      // buy
      return _getTBuyValues(tAmount, currentRate);
    } else {
      // sell
      return _getTSellValues(tAmount, currentRate);
    }
  }

  function _getBuyValues(uint256 amount) private view returns (uint256, uint256, uint256) {
    uint256 teamFee = amount.mul(_buyLiquidityTax).div(100);
    uint256 reflectionFee = amount.mul(_buyReflectionTax).div(100);
    uint256 transferAmount = amount.sub(teamFee).sub(reflectionFee);
    return (transferAmount, reflectionFee, teamFee);
  }

  function _getTBuyValues(
    uint256 amount,
    uint256 currentRate
  )
    private
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    (uint256 tTransferAmount, uint256 reflectionFee, uint256 teamFee) = _getBuyValues(amount);
    uint256 rAmount = amount.mul(currentRate);
    uint256 rTeamFee = teamFee.mul(currentRate);
    uint256 rReflectionFee = reflectionFee.mul(currentRate);
    uint256 rTransferAmount = rAmount.sub(rTeamFee).sub(rReflectionFee);
    return (rAmount, rTransferAmount, rReflectionFee, tTransferAmount, reflectionFee, teamFee, 0);
  }

  function _getTSellValues(
    uint256 tAmount,
    uint256 currentRate
  )
    private
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    uint256 teamFee = tAmount.mul(_sellLiquidityTax + _sellTreasuryTax).div(100);
    uint256 dividendFee = tAmount.mul(_sellDividendTax).div(100);
    uint256 tTransferAmount = tAmount.sub(teamFee).sub(dividendFee);
    return (tAmount, tTransferAmount, 0, tTransferAmount, 0, teamFee, dividendFee);
  }

  function _getRate() private view returns (uint256) {
    (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
    return rSupply.div(tSupply);
  }

  function _getCurrentSupply() private view returns (uint256, uint256) {
    uint256 rSupply = _rTotal;
    uint256 tSupply = _tTotal;
    for (uint256 i = 0; i < _excluded.length; i++) {
      if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply)
        return (_rTotal, _tTotal);
      rSupply = rSupply.sub(_rOwned[_excluded[i]]);
      tSupply = tSupply.sub(_tOwned[_excluded[i]]);
    }
    if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
    return (rSupply, tSupply);
  }

  // We are exposing these functions to be able to manual swap and send
  // in case the token is highly valued and 5M becomes too much
  function manualSwap() external onlyOwner {
    uint256 contractBalance = balanceOf(address(this));
    swapTokensForEth(contractBalance);
  }

  function manualSend() external onlyOwner {
    uint256 contractETHBalance = address(this).balance;
    sendETHToTeam(contractETHBalance);
  }

  function setSwapEnabled(bool enabled) external onlyOwner {
    swapEnabled = enabled;
  }

  function _getMaxTxAmount() private view returns (uint256) {
    return _maxTxAmount;
  }

  function _isSelling(address recipient) private view returns (bool) {
    return recipient == uniswapV2Pair || _isUniswapPair[recipient];
  }

  function _getETHBalance() public view returns (uint256 balance) {
    return address(this).balance;
  }

  function _setTaxes(
      uint256 buyLiquidityTax,
      uint256 buyReflectionTax,
      uint256 sellLiquidityTax,
      uint256 sellTreasuryTax,
      uint256 sellDividendTax
  ) external onlyOwner {
      _buyLiquidityTax = buyLiquidityTax;
      _buyReflectionTax = buyReflectionTax;
      _sellLiquidityTax = sellLiquidityTax;
      _sellTreasuryTax = sellTreasuryTax;
      _sellDividendTax = sellDividendTax;
  }

  function getTaxes() public view returns (
      uint256 buyLiquidityTax,
      uint256 buyReflectionTax,
      uint256 sellLiquidityTax,
      uint256 sellTreasuryTax,
      uint256 sellDividendTax) {
    return (_buyLiquidityTax, _buyReflectionTax, _sellLiquidityTax, _sellTreasuryTax, _sellDividendTax);
  }

  function setWallet(address payable treasuryWallet) external onlyOwner {
    _treasuryWallet = treasuryWallet;
  }

  function _setMaxTxAmount(uint256 maxTxAmount) external onlyOwner {
    require(
      maxTxAmount >= 100000000000000e9,
      'maxTxAmount should be greater than 100000000000000e9'
    );
    _maxTxAmount = maxTxAmount;
  }

  function isUniswapPair(address _pair) external view returns (bool) {
    if (_pair == uniswapV2Pair) return true;
    return _isUniswapPair[_pair];
  }

  function addUniswapPair(address _pair) external onlyOwner {
    _isUniswapPair[_pair] = true;
  }

  function removeUniswapPair(address _pair) external onlyOwner {
    _isUniswapPair[_pair] = false;
  }

  function Airdrop(address[] calldata recipients, uint256 amount) external onlyOwner {
    for (uint256 _i = 0; _i < recipients.length; _i++) {
      transferFrom(msg.sender, recipients[_i], amount);
    }
  }

  function claim() public {
      dividendTracker.processAccount(payable(_msgSender()));
  }

  function withdrawableDividendOf(address account)
      public
      view
      returns (uint256)
  {
      return dividendTracker.withdrawableDividendOf(account);
  }

  function withdrawnDividendOf(address account)
      public
      view
      returns (uint256)
  {
      return dividendTracker.withdrawnDividendOf(account);
  }

  function accumulativeDividendOf(address account)
      public
      view
      returns (uint256)
  {
      return dividendTracker.accumulativeDividendOf(account);
  }

  function getAccountInfo(address account)
      public
      view
      returns (
          address,
          uint256,
          uint256,
          uint256,
          uint256
      )
  {
      return dividendTracker.getAccountInfo(account);
  }

  function getLastClaimTime(address account) public view returns (uint256) {
      return dividendTracker.getLastClaimTime(account);
  }


  function manualSendDividend(uint256 amount, address holder)
      external
      onlyOwner
  {
      dividendTracker.manualSendDividend(amount, holder);
  }

  function excludeFromDividends(address account, bool excluded)
      public
      onlyOwner
  {
      dividendTracker.excludeFromDividends(account, excluded);
  }

  function isExcludedFromDividends(address account)
      public
      view
      returns (bool)
  {
      return dividendTracker.isExcludedFromDividends(account);
  }
}

contract DividendTracker is Ownable, IERC20 {
    address UNISWAPROUTER;

    string private _name = "Inc_DividendTracker";
    string private _symbol = "Inc_DividendTracker";

    uint256 public lastProcessedIndex;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    uint256 private constant magnitude = 2**128;
    uint256 public immutable minTokenBalanceForDividends;
    uint256 private magnifiedDividendPerShare;
    uint256 public totalDividendsDistributed;
    uint256 public totalDividendsWithdrawn;

    address public tokenAddress;

    mapping(address => bool) public excludedFromDividends;
    mapping(address => int256) private magnifiedDividendCorrections;
    mapping(address => uint256) private withdrawnDividends;
    mapping(address => uint256) private lastClaimTimes;

    event DividendsDistributed(address indexed from, uint256 weiAmount);
    event DividendWithdrawn(address indexed to, uint256 weiAmount);
    event ExcludeFromDividends(address indexed account, bool excluded);
    event Claim(address indexed account, uint256 amount);
    event Compound(address indexed account, uint256 amount, uint256 tokens);

    struct AccountInfo {
        address account;
        uint256 withdrawableDividends;
        uint256 totalDividends;
        uint256 lastClaimTime;
    }

    constructor(address _tokenAddress, address _uniswapRouter) {
        minTokenBalanceForDividends = 10000 * (10**18);
        tokenAddress = _tokenAddress;
        UNISWAPROUTER = _uniswapRouter;
    }

    receive() external payable {
        distributeDividends();
    }

    function distributeDividends() public payable {
        require(_totalSupply > 0);
        if (msg.value > 0) {
            magnifiedDividendPerShare =
                magnifiedDividendPerShare +
                ((msg.value * magnitude) / _totalSupply);
            emit DividendsDistributed(msg.sender, msg.value);
            totalDividendsDistributed += msg.value;
        }
    }

    function setBalance(address payable account, uint256 newBalance)
        external
        onlyOwner
    {
        if (excludedFromDividends[account]) {
            return;
        }
        if (newBalance >= minTokenBalanceForDividends) {
            _setBalance(account, newBalance);
        } else {
            _setBalance(account, 0);
        }
    }

    function excludeFromDividends(address account, bool excluded)
        external
        onlyOwner
    {
        require(
            excludedFromDividends[account] != excluded,
            "Inc_DividendTracker: account already set to requested state"
        );
        excludedFromDividends[account] = excluded;
        if (excluded) {
            _setBalance(account, 0);
        } else {
            uint256 newBalance = IERC20(tokenAddress).balanceOf(account);
            if (newBalance >= minTokenBalanceForDividends) {
                _setBalance(account, newBalance);
            } else {
                _setBalance(account, 0);
            }
        }
        emit ExcludeFromDividends(account, excluded);
    }

    function isExcludedFromDividends(address account)
        public
        view
        returns (bool)
    {
        return excludedFromDividends[account];
    }

    function manualSendDividend(uint256 amount, address holder)
        external
        onlyOwner
    {
        uint256 contractETHBalance = address(this).balance;
        payable(holder).transfer(amount > 0 ? amount : contractETHBalance);
    }

    function _setBalance(address account, uint256 newBalance) internal {
        uint256 currentBalance = _balances[account];
        if (newBalance > currentBalance) {
            uint256 addAmount = newBalance - currentBalance;
            _mint(account, addAmount);
        } else if (newBalance < currentBalance) {
            uint256 subAmount = currentBalance - newBalance;
            _burn(account, subAmount);
        }
    }

    function _mint(address account, uint256 amount) private {
        require(
            account != address(0),
            "Inc_DividendTracker: mint to the zero address"
        );
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
        magnifiedDividendCorrections[account] =
            magnifiedDividendCorrections[account] -
            int256(magnifiedDividendPerShare * amount);
    }

    function _burn(address account, uint256 amount) private {
        require(
            account != address(0),
            "Inc_DividendTracker: burn from the zero address"
        );
        uint256 accountBalance = _balances[account];
        require(
            accountBalance >= amount,
            "Inc_DividendTracker: burn amount exceeds balance"
        );
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
        magnifiedDividendCorrections[account] =
            magnifiedDividendCorrections[account] +
            int256(magnifiedDividendPerShare * amount);
    }

    function processAccount(address payable account)
        public
        onlyOwner
        returns (bool)
    {
        uint256 amount = _withdrawDividendOfUser(account);
        if (amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount);
            return true;
        }
        return false;
    }

    function _withdrawDividendOfUser(address payable account)
        private
        returns (uint256)
    {
        uint256 _withdrawableDividend = withdrawableDividendOf(account);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[account] += _withdrawableDividend;
            totalDividendsWithdrawn += _withdrawableDividend;
            emit DividendWithdrawn(account, _withdrawableDividend);
            (bool success, ) = account.call{
                value: _withdrawableDividend,
                gas: 3000
            }("");
            if (!success) {
                withdrawnDividends[account] -= _withdrawableDividend;
                totalDividendsWithdrawn -= _withdrawableDividend;
                return 0;
            }
            return _withdrawableDividend;
        }
        return 0;
    }

    function compoundAccount(address payable account)
        public
        onlyOwner
        returns (bool)
    {
        (uint256 amount, uint256 tokens) = _compoundDividendOfUser(account);
        if (amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Compound(account, amount, tokens);
            return true;
        }
        return false;
    }

    function _compoundDividendOfUser(address payable account)
        private
        returns (uint256, uint256)
    {
        uint256 _withdrawableDividend = withdrawableDividendOf(account);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[account] += _withdrawableDividend;
            totalDividendsWithdrawn += _withdrawableDividend;
            emit DividendWithdrawn(account, _withdrawableDividend);

            IUniswapV2Router02 uniswapV2Router = IUniswapV2Router02(
                UNISWAPROUTER
            );

            address[] memory path = new address[](2);
            path[0] = uniswapV2Router.WETH();
            path[1] = address(tokenAddress);

            bool success;
            uint256 tokens;

            uint256 initTokenBal = IERC20(tokenAddress).balanceOf(account);
            try
                uniswapV2Router
                    .swapExactETHForTokensSupportingFeeOnTransferTokens{
                    value: _withdrawableDividend
                }(0, path, address(account), block.timestamp)
            {
                success = true;
                tokens = IERC20(tokenAddress).balanceOf(account) - initTokenBal;
            } catch Error(
                string memory /*err*/
            ) {
                success = false;
            }

            if (!success) {
                withdrawnDividends[account] -= _withdrawableDividend;
                totalDividendsWithdrawn -= _withdrawableDividend;
                return (0, 0);
            }

            return (_withdrawableDividend, tokens);
        }
        return (0, 0);
    }

    function withdrawableDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return accumulativeDividendOf(account) - withdrawnDividends[account];
    }

    function withdrawnDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return withdrawnDividends[account];
    }

    function accumulativeDividendOf(address account)
        public
        view
        returns (uint256)
    {
        int256 a = int256(magnifiedDividendPerShare * balanceOf(account));
        int256 b = magnifiedDividendCorrections[account]; // this is an explicit int256 (signed)
        return uint256(a + b) / magnitude;
    }

    function getAccountInfo(address account)
        public
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        AccountInfo memory info;
        info.account = account;
        info.withdrawableDividends = withdrawableDividendOf(account);
        info.totalDividends = accumulativeDividendOf(account);
        info.lastClaimTime = lastClaimTimes[account];
        return (
            info.account,
            info.withdrawableDividends,
            info.totalDividends,
            info.lastClaimTime,
            totalDividendsWithdrawn
        );
    }

    function getLastClaimTime(address account) public view returns (uint256) {
        return lastClaimTimes[account];
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("Inc_DividendTracker: method not implemented");
    }

    function allowance(address, address)
        public
        pure
        override
        returns (uint256)
    {
        revert("Inc_DividendTracker: method not implemented");
    }

    function approve(address, uint256) public pure override returns (bool) {
        revert("Inc_DividendTracker: method not implemented");
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        revert("Inc_DividendTracker: method not implemented");
    }
}