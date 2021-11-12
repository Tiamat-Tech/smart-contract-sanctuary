// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import "./utils/LPSwapSupport.sol";
import "./utils/NoBSReflections.sol";

contract TestTX is IBEP20, LPSwapSupport, NoBSReflections {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    event Burn(address indexed from, uint256 tokensBurned);

    struct Fees{
        uint256 liquidity;
        uint256 marketing;
        uint256 tokenReflection;
        uint256 burn;
        uint256 divisor;
    }

    struct TokenTracker{
        uint256 liquidity;
        uint256 marketingTokens;
        uint256 reward;
    }

//    uint8 private initSteps = 2;

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public isBlacklisted;
    mapping (address => bool) public _isExcludedFromFee;
    mapping (address => bool) public _isExcludedFromWalletRestriction;
    mapping (address => bool) public _isExcludedFromTxRestriction;

    mapping (address => bool) private automatedMarketMakerPairs;

    string private _name;
    string private _symbol;
    uint256 private _decimals;
    uint256 private  _totalSupply;

    bool public tradingIsEnabled;

    // Trackers for various pending token swaps and fees
    Fees public sellFees;
    Fees public transferFees;
    TokenTracker public tokenTracker;

    uint256 public _maxTxAmount;
    uint256 public maxWalletSize;

    address payable public marketingWallet;

    constructor (address routerAddress, address tokenOwner, address _marketingWallet) LPSwapSupport() public {
        _name = "TestTX";
        _symbol = "TTX";
        _decimals = 18;
        _totalSupply = 1 * 10 ** 15 * 10 ** _decimals;

        swapsEnabled = false;

        minTokenSpendAmount = _totalSupply.div(50000);
        _maxTxAmount = _totalSupply.mul(3).div(1000);
        maxWalletSize = _totalSupply.div(100);

        liquidityReceiver = deadAddress;

        marketingWallet = payable(_marketingWallet);
        updateRouterAndPair(routerAddress);

        sellFees = Fees({
            liquidity: 6,
            marketing: 6,
            tokenReflection: 5,
            burn: 1,
            divisor: 100
        });

        transferFees = Fees({
            liquidity: 5,
            marketing: 5,
            tokenReflection: 5,
            burn: 1,
            divisor: 100
        });

        tokenTracker = TokenTracker({
            liquidity: 0,
            marketingTokens: 0,
            reward: 0
        });

        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadAddress] = true;
        _isExcludedFromFee[_msgSender()] = true;

        _owner = tokenOwner;
        balances[tokenOwner] = _totalSupply;
        emit Transfer(address(this), _owner, balances[_owner]);
    }

    function init() public override {
        require(_isExcludedFromFee[_msgSender()]);
        super.init();
        reflector.excludeFromReward(address(this), true);
        reflector.excludeFromReward(pancakePair, true);
        reflector.excludeFromReward(deadAddress, true);
        // TODO
    }

    fallback() external payable {}

    //to recieve BNB from pancakeswapV2Router when swaping
    receive() external payable {}

    function name() public override view returns (string memory) {
        return _name;
    }

    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    function decimals() public override view returns (uint8) {
        return uint8(_decimals);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function _balanceOf(address account) internal view override returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "Transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "Decreased allowance below zero"));
        return true;
    }

    function setMarketingWallet(address _marketingWallet) public onlyOwner {
        marketingWallet = payable(_marketingWallet);
    }

    function getOwner() external override view returns(address){
        return owner();
    }

    function excludeFromFee(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromFee[account] = shouldExclude;
    }

    function excludeFromTxSizeRestriction(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromTxRestriction[account] = shouldExclude;
    }

    function excludeFromWalletSizeRestriction(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromWalletRestriction[account] = shouldExclude;
    }

    function blacklistAccount(address account, bool shouldBlacklist) public onlyOwner {
        isBlacklisted[account] = shouldBlacklist;
    }

    function _calculateFees(uint256 amount, Fees memory _fees) private pure returns(uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee, uint256 burnFee) {
        liquidityFee = amount.mul(_fees.liquidity).div(_fees.divisor);
        marketingFee = amount.mul(_fees.marketing).div(_fees.divisor);
        burnFee = amount.mul(_fees.burn).div(_fees.divisor);
        reflectionFee = amount.mul(_fees.tokenReflection).div(_fees.divisor);
    }

    function _takeFees(address from, uint256 amount, Fees memory _fees) private returns(uint256 transferAmount){
        (uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee, uint256 burnFee) = _calculateFees(amount, _fees);

        uint256 totalFees = liquidityFee.add(marketingFee).add(reflectionFee);

        TokenTracker memory _tokenTracker = tokenTracker;

        tokenTracker.liquidity = _tokenTracker.liquidity.add(liquidityFee);
        tokenTracker.marketingTokens = _tokenTracker.marketingTokens.add(marketingFee);
        tokenTracker.reward = _tokenTracker.reward.add(reflectionFee);

        balances[deadAddress] = balances[deadAddress].add(burnFee);
        emit Burn(from, burnFee);
        balances[address(this)] = balances[address(this)].add(totalFees);
        totalFees = totalFees.add(burnFee);
        transferAmount = amount.sub(totalFees);
    }

    function updateRegularFees(uint256 _liquidity, uint256 _marketing, uint256 _tokenReflection, uint256 _burn, uint256 _divisor) external onlyOwner {
        transferFees = Fees({
            liquidity: _liquidity,
            marketing: _marketing,
            tokenReflection: _tokenReflection,
            burn: _burn,
            divisor: _divisor
        });
    }

    function updateBuySellFees(uint256 _liquidity, uint256 _marketing, uint256 _tokenReflection, uint256 _burn, uint256 _divisor) external onlyOwner {
        sellFees = Fees({
            liquidity: _liquidity,
            marketing: _marketing,
            tokenReflection: _tokenReflection,
            burn: _burn,
            divisor: _divisor
        });
    }

    function setMaxTx(uint256 maxTxTokens) public onlyOwner {
        _maxTxAmount = maxTxTokens  * 10 ** _decimals;
    }

    function setMaxWalletPercent(uint256 maxWalletPct) public onlyOwner {
        maxWalletSize = _totalSupply.div(maxWalletPct);
    }

    function burn(uint256 burnAmount) public {
        require(_msgSender() != address(0), "BEP20: transfer from the zero address");
        require(balanceOf(_msgSender()) > burnAmount, "Insufficient funds in account");
        _burn(_msgSender(), burnAmount);
    }

    function _burn(address from, uint256 burnAmount) private {
        _transferStandard(from, deadAddress, burnAmount, burnAmount);
        emit Burn(from, burnAmount);
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0) && spender != address(0), "BEP20: Approve involves the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "BEP20: Transfer involves the zero address");
        require(!isBlacklisted[to] && !isBlacklisted[from], "Address blacklisted and cannot trade");
//        require(initSteps == 0, "Contract is not fully initialized");
        if(amount == 0){
            _transferStandard(from, to, 0, 0);
        }
        uint256 transferAmount = amount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(tradingIsEnabled, "Trading has not yet opened");

            if(!_isExcludedFromTxRestriction[from] && !_isExcludedFromTxRestriction[to]){
                require(amount <= _maxTxAmount, "Transaction size is too large");
            }

            if(automatedMarketMakerPairs[from]){ // Buy
                transferAmount = _takeFees(from, amount, transferFees);
                require(_isExcludedFromWalletRestriction[to] || balances[to].add(transferAmount) <= maxWalletSize, "Wallet size exceeded by transaction");
            } else if(automatedMarketMakerPairs[to]){ // Sell
                transferAmount = _takeFees(from, amount, sellFees);
            } else { // Transfer
                transferAmount = _takeFees(from, amount, transferFees);
                require(_isExcludedFromWalletRestriction[to] || balances[to].add(transferAmount) <= maxWalletSize, "Wallet size exceeded by transaction");
            }
            if(!inSwap && from != pancakePair && from != address(pancakeRouter) && tradingIsEnabled) {
                selectSwapEvent();
            }
        }

        _transferStandard(from, to, amount, transferAmount);

        logTransfer(from, balances[from], to, balances[to]);
    }

    function pushSwap() external {
        if(!inSwap && tradingIsEnabled)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        if(!swapsEnabled){return;}
        uint256 contractBalance = address(this).balance;
        TokenTracker memory _tokenTracker = tokenTracker;

        if(_tokenTracker.reward >= minTokenSpendAmount){

            uint256 swappedTokens = swapTokensForCurrency(_tokenTracker.reward);
            uint256 swappedCurrency = address(this).balance.sub(contractBalance);
            reflector.deposit{value: swappedCurrency}();
            tokenTracker.reward = _tokenTracker.reward.sub(swappedTokens);

        } else if(_tokenTracker.liquidity >= minTokenSpendAmount){

            swapAndLiquify(_tokenTracker.liquidity);
            tokenTracker.liquidity = 0;

        } else if(_tokenTracker.marketingTokens >= minTokenSpendAmount){

            uint256 swappedTokens = swapTokensForCurrencyAdv(address(this), _tokenTracker.marketingTokens, marketingWallet);
            tokenTracker.marketingTokens = _tokenTracker.marketingTokens.sub(swappedTokens);

        } else {
            processRewards();
        }
    }

    function updateLPPair(address newAddress) public override onlyOwner {
        super.updateLPPair(newAddress);
        registerPairAddress(newAddress, true);
    }

    function registerPairAddress(address ammPair, bool isLPPair) public onlyOwner {
        automatedMarketMakerPairs[ammPair] = isLPPair;
    }

    function _transferStandard(address sender, address recipient, uint256 amount, uint256 transferAmount) private {
        balances[sender] = balances[sender].sub(amount);
        balances[recipient] = balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function openTrading() external onlyOwner {
        tradingIsEnabled = !tradingIsEnabled;
        swapsEnabled = tradingIsEnabled;
    }
}