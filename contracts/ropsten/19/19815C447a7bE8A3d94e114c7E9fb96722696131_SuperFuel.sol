// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import '@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';
import '@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakePair.sol';
import '@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol';
import 'pancakeswap-peripheral/contracts/interfaces/IPancakeRouter02.sol';
import './utils/Ownable.sol';
import './utils/Manageable.sol';
import "./utils/Presale.sol";
import "./DividendDistributor.sol";
import "./utils/LockableFunction.sol";
import "./utils/LPSwapSupport.sol";
import "./utils/AntiLPSniper.sol";

contract SuperFuel is IBEP20, Manageable, AntiLPSniper, LockableFunction, LPSwapSupport {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    event Burn(address indexed from, uint256 tokensBurned);

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event UpdateFee(string indexed feeName, uint256 oldFee, uint256 newFee);

    struct Fees{
        uint256 liquidity;
        uint256 marketing;
        uint256 tokenReflection;
        uint256 buyback;
        uint256 lottery;
        uint256 divisor;
    }

    struct TokenTracker{
        uint256 liquidity;
        uint256 marketingTokens;
        uint256 reward;
        uint256 buyback;
        uint256 lottery;
    }

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private blacklist;
    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcludedFromReward;

    string private _name;
    string private _symbol;
    uint256 private _decimals;
    uint256 private  _totalSupply;

    bool tradingIsEnabled;

    // Trackers for various pending token swaps and fees
    Fees public fees;
    Fees public transferFees;
    TokenTracker public tokenTracker;
    TokenTracker public feeDistributionTracker;

    uint256 public _maxTxAmount;
    uint256 public tokenSwapThreshold;

    uint256 public gasForProcessing = 300000;

    // TODO - Change from test setup
    address payable public marketingWallet;
    address payable public buybackContract;
    address payable public lotteryContract;
    IDividendDistributor public dividendDistributor;

    constructor (uint256 _supply, address routerAddress, address tokenOwner, address _marketingWallet, address rewardsToken) Manageable(tokenOwner) public {
        _name = "SuperFuel";
        _symbol = "SFUEL";
        _decimals = 9;
        _totalSupply = _supply * 10 ** _decimals;

        _maxTxAmount = _totalSupply;
        tokenSwapThreshold = _maxTxAmount.div(10000);

        liquidityReceiver = deadAddress;

        dividendDistributor = new DividendDistributor(routerAddress, rewardsToken);
        marketingWallet = address(this);
        buybackContract = address(this);
        lotteryContract = address(this);

//        updateRouterAndPair(routerAddress);
        pancakeRouter = IPancakeRouter02(routerAddress);
//        setPair();
//        pancakePair = IPancakeFactory(pancakeRouter.factory()).createPair(address(this), pancakeRouter.WETH());

        fees = Fees({
            liquidity: 2,
            marketing: 3,
            tokenReflection: 7,
            buyback: 2,
            lottery: 5,
            divisor: 100
        });

        transferFees = Fees({
            liquidity: 5,
            marketing: 0,
            tokenReflection: 0,
            buyback: 0,
            lottery: 0,
            divisor: 100
        });

        tokenTracker = TokenTracker({
            liquidity: 0,
            marketingTokens: 0,
            reward: 0,
            buyback: 0,
            lottery: 0
        });

        marketingWallet = payable(_marketingWallet);

        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[address(dividendDistributor)] = true;
        _isExcludedFromFee[lotteryContract] = true;
        _isExcludedFromFee[buybackContract] = true;

        _owner = tokenOwner;
        balances[tokenOwner] = _totalSupply;
//        emit Transfer(address(0), address(this), _presaleReserve);
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

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcludedFromReward[account];
    }

    function setMarketingWallet(address _marketingWallet) public onlyOwner {
        marketingWallet = payable(_marketingWallet);
    }

    function getOwner() external override view returns(address){
        return owner();
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 1000000, "Gas requirement is between 200,000 and 1,000,000");
        require(newValue != gasForProcessing, "Gas requirement already set to that value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function withdrawForeignTokens(address receiver, address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Token address is zero");
        require(tokenAddress != address(this), "Cannot force withdraw SuperFuel tokens");
        require(IBEP20(tokenAddress).balanceOf(address(this)) > 0, "No balance to withdraw");

        uint256 balance = IBEP20(tokenAddress).balanceOf(address(this));
        IBEP20(tokenAddress).transfer(receiver, balance);
    }

    function excludeFromFee(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromFee[account] = shouldExclude;
    }

    function _calculateFees(uint256 amount, bool isTransfer) private returns(uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) {
        Fees memory _fees;
        if(isTransfer)
            _fees = transferFees;
        else
            _fees = fees;
        liquidityFee = amount.mul(_fees.liquidity).div(_fees.divisor);
        marketingFee = amount.mul(_fees.marketing).div(_fees.divisor);
        buybackFee = amount.mul(_fees.buyback).div(_fees.divisor);
        reflectionFee = amount.mul(_fees.tokenReflection).div(_fees.divisor);
        lotteryFee = amount.mul(_fees.lottery).div(_fees.divisor);

        feeDistributionTracker.liquidity = feeDistributionTracker.liquidity.add(_fees.liquidity);
        feeDistributionTracker.marketingTokens = feeDistributionTracker.marketingTokens.add(_fees.marketing);
        feeDistributionTracker.buyback = feeDistributionTracker.buyback.add(_fees.buyback);
        feeDistributionTracker.reward = feeDistributionTracker.reward.add(_fees.tokenReflection);
        feeDistributionTracker.lottery = feeDistributionTracker.lottery.add(_fees.lottery);
    }
    ////////////////////////////////////////////////////// - TODO Rewrite
    function _takeFees(address from, uint256 amount, bool isTransfer) private returns(uint256 transferAmount){
        (uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) = _calculateFees(amount, isTransfer);
        uint256 totalFees = liquidityFee.add(marketingFee).add(buybackFee).add(reflectionFee).add(lotteryFee);

        tokenTracker.liquidity = tokenTracker.liquidity.add(liquidityFee);
        tokenTracker.marketingTokens = tokenTracker.marketingTokens.add(marketingFee);
        tokenTracker.buyback = tokenTracker.buyback.add(buybackFee);
        tokenTracker.reward = tokenTracker.reward.add(reflectionFee);
        tokenTracker.lottery = tokenTracker.lottery.add(lotteryFee);

        _transferStandard(from, address(this), totalFees, totalFees);
//        balances[address(this)] = balances[address(this)].add(totalFees);
        transferAmount = amount.sub(totalFees);
    }
    ////////////////////////////////////////////////////// - TODO Rewrite

    function updateTransferFees(uint256 _liquidity, uint256 _marketing, uint256 _tokenReflection, uint256 _buyback, uint256 _lottery, uint256 _divisor) external onlyOwner {
        transferFees = Fees({
            liquidity: _liquidity,
            marketing: _marketing,
            tokenReflection: _tokenReflection,
            buyback: _buyback,
            lottery: _lottery,
            divisor: _divisor
        });
    }

    function updateBuySellFees(uint256 _liquidity, uint256 _marketing, uint256 _tokenReflection, uint256 _buyback, uint256 _lottery, uint256 _divisor) external onlyOwner {
        fees = Fees({
            liquidity: _liquidity,
            marketing: _marketing,
            tokenReflection: _tokenReflection,
            buyback: _buyback,
            lottery: _lottery,
            divisor: _divisor
        });
    }

    function setTokenSwapThreshold(uint256 minTokensBeforeTransfer) public onlyOwner {
        tokenSwapThreshold = minTokensBeforeTransfer * 10 ** _decimals;
    }

    function setMaxSellTx(uint256 maxTxTokens) public onlyOwner {
        _maxTxAmount = maxTxTokens  * 10 ** _decimals;
    }

    function burn(uint256 burnAmount) public {
        require(_msgSender() != address(0), "ERC20: transfer from the zero address");
        require(balanceOf(_msgSender()) > burnAmount, "Insufficient funds in account");
        _burn(_msgSender(), burnAmount);
    }

    function _burn(address from, uint256 burnAmount) private {
        _transferStandard(from, deadAddress, burnAmount, burnAmount);
        emit Burn(from, burnAmount);
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer( address from, address to, uint256 amount) private neitherBlacklisted(from, to){
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 transferAmount = amount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(!inSwap && from != pancakePair && tradingIsEnabled) {
                selectSwapEvent();
            }
            transferAmount = _takeFees(from, amount, false);
        } else if(from != address(this) && to != address(this)){
            dividendDistributor.process(gasForProcessing);
        }
        try dividendDistributor.setShare(payable(from), balanceOf(from)) {} catch {}
        try dividendDistributor.setShare(payable(to), balanceOf(to)) {} catch {}
        _transferStandard(from, to, amount, transferAmount);
    }

    function pushSwap() external {
        if(!inSwap && tradingIsEnabled)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        uint256 contractBalance = address(this).balance;
        uint256 tokenContractBalance = balances[address(this)];

        if(tokenContractBalance >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.reward.add(tokenTracker.lottery).add(tokenTracker.marketingTokens).add(tokenTracker.buyback);

            if(tokenContractBalance > tokenTracker.liquidity){
                swapTokensForCurrency(tokenContractBalance);
                uint256 swappedCurrency = address(this).balance.sub(contractBalance);
                uint256 relativeDistributions = feeDistributionTracker.buyback.add(feeDistributionTracker.marketingTokens).add(feeDistributionTracker.lottery).add(feeDistributionTracker.reward);

                uint256 sendValue = swappedCurrency.mul(feeDistributionTracker.reward).div(relativeDistributions);
                uint256 sentSoFar = sendValue;
                address(dividendDistributor).call{value: sendValue}("");

                sendValue = swappedCurrency.mul(feeDistributionTracker.lottery).div(relativeDistributions);
                lotteryContract.call{value: sendValue}("");
                sentSoFar = sentSoFar.add(sendValue);

                sendValue = swappedCurrency.mul(feeDistributionTracker.marketingTokens).div(relativeDistributions);
                marketingWallet.call{value: sendValue}("");
                sentSoFar = sentSoFar.add(sendValue);

                sendValue = swappedCurrency.sub(sentSoFar);
                buybackContract.call{value: sendValue}("");

                feeDistributionTracker.buyback = 0;
                feeDistributionTracker.marketingTokens = 0;
                feeDistributionTracker.lottery = 0;
                feeDistributionTracker.reward = 0;

                tokenTracker.buyback = 0;
                tokenTracker.marketingTokens = 0;
                tokenTracker.lottery = 0;
                tokenTracker.reward = 0;
            } else {
                swapAndLiquify(tokenTracker.liquidity);
                tokenTracker.liquidity = 0;
                feeDistributionTracker.liquidity = 0;
            }

        } else {
            try dividendDistributor.process(gasForProcessing) {} catch {}
        }
    }

    function sendBNBTo(address payable to, uint256 amount) private {
        require(address(this).balance >= amount);
        to.transfer(amount);
    }

    function _transferStandard(address sender, address recipient, uint256 amount, uint256 transferAmount) private {
        balances[sender] = balances[sender].sub(amount);
        balances[recipient] = balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function openTrading() external onlyOwner {
        require(!tradingIsEnabled, "Trading already open");
        tradingIsEnabled = true;
    }

    function updateDividendDistributor(address newDistributorAddress) external onlyOwner {
        require(address(dividendDistributor) != newDistributorAddress, "Distribution contract already set to that address");
        dividendDistributor = IDividendDistributor(newDistributorAddress);
    }

    function setRewardToCurrency() external onlyOwner {
        dividendDistributor.setRewardToCurrency();
    }
    function setRewardToToken(address _tokenAddress) external onlyOwner{
        dividendDistributor.setRewardToToken(_tokenAddress);
    }
}