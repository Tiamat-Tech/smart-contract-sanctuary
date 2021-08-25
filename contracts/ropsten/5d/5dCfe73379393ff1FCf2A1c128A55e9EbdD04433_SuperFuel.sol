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
import "./utils/DividendDistributor.sol";
import "./utils/LockableFunction.sol";
import "./utils/LPSwapSupport.sol";
import "./utils/AntiLPSniper.sol";

contract SuperFuel is IBEP20, Manageable, AntiLPSniper, LockableFunction, LPSwapSupport {
    using SafeMath for uint256;
    using Address for address;

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

    uint256 public _maxTxAmount;
    uint256 public tokenSwapThreshold;

    uint256 public gasForProcessing = 300000;

    address payable private marketingWallet;
    IDividendDistributor public dividendDistributor;

    constructor (uint256 _supply, address routerAddress, address tokenOwner, address _marketingWallet, address rewardsToken) Manageable(tokenOwner) public {
        _name = "SuperFuel";
        _symbol = "SFUEL";
        _decimals = 9;
        _totalSupply = _supply * 10 ** _decimals;

        _maxTxAmount = _totalSupply.div(200);
        tokenSwapThreshold = _maxTxAmount.div(10000);

        liquidityReceiver = deadAddress;

        dividendDistributor = new DividendDistributor(routerAddress, rewardsToken);


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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
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

    // TODO - Turn off individually?
    function _calculateFees(uint256 amount) private returns(uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) {
        liquidityFee = amount.mul(fees.liquidity).div(fees.divisor);
        marketingFee = amount.mul(fees.marketing).div(fees.divisor);
        buybackFee = amount.mul(fees.buyback).div(fees.divisor);
        reflectionFee = amount.mul(fees.tokenReflection).div(fees.divisor);
        lotteryFee = amount.mul(fees.lottery).div(fees.divisor);
    }
    ////////////////////////////////////////////////////// - TODO Rewrite
    function _takeFees(uint256 amount) private returns(uint256 transferAmount){
        (uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) = _calculateFees(amount);
        uint256 totalFees = liquidityFee.add(marketingFee).add(buybackFee).add(reflectionFee).sub(lotteryFee);

        tokenTracker.liquidity = tokenTracker.liquidity.add(liquidityFee);
        tokenTracker.marketingTokens = tokenTracker.marketingTokens.add(marketingFee);
        tokenTracker.buyback = tokenTracker.buyback.add(buybackFee);
        tokenTracker.reward = tokenTracker.reward.add(reflectionFee);
        tokenTracker.lottery = tokenTracker.lottery.add(lotteryFee);

        balances[address(this)] = balances[address(this)].add(totalFees);
        transferAmount = amount.sub(totalFees);
    }
    ////////////////////////////////////////////////////// - TODO Rewrite
    function setLiquidityFee(uint256 _liquidityFee) external onlyOwner() {
        emit UpdateFee("LiquidityFee", fees.liquidity, _liquidityFee);
        fees.liquidity = _liquidityFee;
    }

    function setMarketingFee(uint256 _marketingFee) external onlyOwner() {
        emit UpdateFee("ProjectWalletFee", fees.marketing, _marketingFee);
        fees.marketing = _marketingFee;
    }

    function setRewardTokenFee(uint256 _rewardTokenFee) external onlyOwner() {
        emit UpdateFee("RewardTokenFee", fees.tokenReflection, _rewardTokenFee);
        fees.tokenReflection = _rewardTokenFee;
    }

    function setBuybackFee(uint256 _buybackFee) external onlyOwner() {
        emit UpdateFee("BuybackFee", fees.buyback, _buybackFee);
        fees.buyback = _buybackFee;
    }

    function setLotteryFee(uint256 _lotteryFee) external onlyOwner() {
        emit UpdateFee("BuybackFee", fees.lottery, _lotteryFee);
        fees.lottery = _lotteryFee;
    }

    function setFeeDivisor(uint256 _divisor) external onlyOwner() {
        emit UpdateFee("Divisor", fees.divisor, _divisor);
        fees.divisor = _divisor;
    }

    function settokenSwapThreshold(uint256 swapNumber) public onlyOwner {
        tokenSwapThreshold = swapNumber * 10 ** _decimals;
    }

    function setMaxTx(uint256 maxTxPercent) public onlyOwner {
        _maxTxAmount = maxTxPercent  * 10 ** _decimals;
    }

    function burn(uint256 burnAmount) public {
        require(balanceOf(_msgSender()) > burnAmount, "Insufficient funds in account");
        _burn(_msgSender(), burnAmount);
    }


    function _burn(address from, uint256 burnAmount) private returns(uint256) {
        require(from != address(0), "ERC20: transfer from the zero address");
        // TODO - Discuss type of burn
        return 0;
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
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is the token balance of this contract address counter for one
        // of the possible token swap events is over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is pancakeswap pair.

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(!inSwap && from != pancakePair && tradingIsEnabled) {
                selectSwapEvent();
            }
            transferAmount = _takeFees(amount);
        } else {
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
        uint256 tokenContractBalance = balances[address(this)];
        if(tokenTracker.reward >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.reward;

            if(tokenContractBalance >= _maxTxAmount)
            {
                tokenContractBalance = _maxTxAmount;
            }

            swapTokensForCurrencyAdv(address(this), tokenContractBalance, address(dividendDistributor));

            tokenTracker.reward = tokenTracker.reward.sub(tokenContractBalance);

//        } else if(tokenTracker.lottery >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.lottery;

            if(tokenContractBalance >= _maxTxAmount)
            {
                tokenContractBalance = _maxTxAmount;
            }

            swapTokensForCurrency(tokenContractBalance);
            //            sendBNBTo(projectWallet, address(this).balance);
            tokenTracker.lottery = tokenTracker.lottery.sub(tokenContractBalance);

//        } else if(tokenTracker.buyback >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.buyback;

            if(tokenContractBalance >= _maxTxAmount)
            {
                tokenContractBalance = _maxTxAmount;
            }

            swapTokensForCurrency(tokenContractBalance);
            //            sendBNBTo(projectWallet, address(this).balance);
            tokenTracker.buyback = tokenTracker.buyback.sub(tokenContractBalance);

//        }else if(tokenTracker.liquidity >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.liquidity;

            if(tokenContractBalance >= _maxTxAmount)
            {
                tokenContractBalance = _maxTxAmount;
            }
            // Add liquidity
            swapAndLiquify(tokenContractBalance);
            tokenTracker.liquidity = tokenTracker.liquidity.sub(tokenContractBalance);

//        }else if(tokenTracker.marketingTokens >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.marketingTokens;

            if(tokenContractBalance >= _maxTxAmount)
            {
                tokenContractBalance = _maxTxAmount;
            }
            // Swap for rewards contract
            swapTokensForCurrency(tokenContractBalance);
            tokenTracker.marketingTokens = tokenTracker.marketingTokens.sub(tokenContractBalance);


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

    function setRewardToCurrency() external onlyOwner {
        dividendDistributor.setRewardToCurrency();
    }
    function setRewardToToken(address _tokenAddress) external onlyOwner{
        dividendDistributor.setRewardToToken(_tokenAddress);
    }
}