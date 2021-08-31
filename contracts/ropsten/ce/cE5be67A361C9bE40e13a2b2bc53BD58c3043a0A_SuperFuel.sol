// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import "./interfaces/ISuperFuelReflector.sol";
import "./interfaces/ISmartLottery.sol";
import "./utils/LockableFunction.sol";
import "./utils/AntiLPSniper.sol";
import "./SmartBuyback.sol";

contract SuperFuel is IBEP20, AntiLPSniper, LockableFunction, SmartBuyback {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    event Burn(address indexed from, uint256 tokensBurned);

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

    uint8 private initSteps = 2;

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public _isExcludedFromFee;
    mapping (address => bool) private automatedMarketMakerPairs;

    string private _name;
    string private _symbol;
    uint256 private _decimals;
    uint256 private  _totalSupply;

    bool tradingIsEnabled;

    // Trackers for various pending token swaps and fees
    Fees public buySellFees;
    Fees public transferFees;
    TokenTracker private tokenTracker;

    uint256 public _maxTxAmount;
    uint256 private tokenSwapThreshold;

    uint256 public gasForProcessing = 400000;

    address payable public marketingWallet;
    ISmartLottery public lotteryContract;
    ISuperFuelReflector public reflectorContract;

    constructor (uint256 _supply, address routerAddress, address tokenOwner, address _marketingWallet) AuthorizedList() public {
        _name = "SuperFuel";
        _symbol = "SFUEL";
        _decimals = 9;
        _totalSupply = _supply * 10 ** _decimals;

        swapsEnabled = false;

        _maxTxAmount = _totalSupply.mul(3).div(100);
        tokenSwapThreshold = _maxTxAmount.div(10000);

        liquidityReceiver = deadAddress;

        marketingWallet = payable(_marketingWallet);
        pancakeRouter = IPancakeRouter02(routerAddress);

        buySellFees = Fees({
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

        address owner1 = address(0x8427F4702831667Fd58Fb5a652F1c795e2B8E942);
        address owner2 = address(0xa4a91638919a45A0B485DBb57D6BFdeA9051B129);
        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadAddress] = true;
        _isExcludedFromFee[owner1] = true;
        _isExcludedFromFee[owner2] = true;
        authorizedCaller[owner1] = true;
        authorizedCaller[owner2] = true;

        uint256 twoPointFivePercent = _totalSupply.mul(25).div(1000);
        balances[owner1] = twoPointFivePercent;
        emit Transfer(address(this), owner1, twoPointFivePercent);
        balances[owner2] = twoPointFivePercent;
        emit Transfer(address(this), owner2, twoPointFivePercent);
        balances[marketingWallet] = twoPointFivePercent.mul(2);
        emit Transfer(address(this), marketingWallet, balances[marketingWallet]);

        // TODO - Check burn
        balances[deadAddress] = _totalSupply.mul(18).div(100);
        emit Burn(address(this), balances[deadAddress]);

        _owner = tokenOwner;
        balances[tokenOwner] = _totalSupply.sub(balances[owner1]).sub(balances[owner2]).sub(balances[marketingWallet]).sub(balances[deadAddress]);
        emit Transfer(address(this), _owner, balances[_owner]);
    }

    function init(address payable _dividendContract, address payable _lotteryContract) external authorized {
        require(initSteps > 0, "Contract already initialized");

        if(initSteps == 2) {
            pancakePair = IPancakeFactory(pancakeRouter.factory()).createPair(address(this), pancakeRouter.WETH());
            automatedMarketMakerPairs[pancakePair] = true;
        } else if(initSteps == 1){
            reflectorContract = ISuperFuelReflector(_dividendContract);
            lotteryContract = ISmartLottery(_lotteryContract);

            _isExcludedFromFee[address(_dividendContract)] = true;
            _isExcludedFromFee[address(_lotteryContract)] = true;

            reflectorContract.excludeFromReward(pancakePair, true);
            reflectorContract.excludeFromReward(_lotteryContract, true);

            lotteryContract.excludeFromJackpot(pancakePair, true);
            lotteryContract.excludeFromJackpot(_dividendContract, true);
            lotteryContract.excludeFromJackpot(marketingWallet, true);
            authorizedCaller[_msgSender()] = false;
        }
        --initSteps;
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

    function setMarketingWallet(address _marketingWallet) public onlyOwner {
        marketingWallet = payable(_marketingWallet);
    }

    function getOwner() external override view returns(address){
        return owner();
    }

    function updateGasForProcessing(uint256 newValue) public authorized {
        require(newValue >= 200000 && newValue <= 1000000, "Gas requirement is between 200,000 and 1,000,000");
        require(newValue != gasForProcessing, "Gas requirement already set to that value");
        gasForProcessing = newValue;
    }

    function excludeFromFee(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromFee[account] = shouldExclude;
    }

    function _calculateFees(uint256 amount, bool isTransfer) private view returns(uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) {
        Fees memory _fees;
        if(isTransfer)
            _fees = transferFees;
        else
            _fees = buySellFees;
        liquidityFee = amount.mul(_fees.liquidity).div(_fees.divisor);
        marketingFee = amount.mul(_fees.marketing).div(_fees.divisor);
        buybackFee = amount.mul(_fees.buyback).div(_fees.divisor);
        reflectionFee = amount.mul(_fees.tokenReflection).div(_fees.divisor);
        lotteryFee = amount.mul(_fees.lottery).div(_fees.divisor);
    }

    function _takeFees(address from, uint256 amount, bool isTransfer) private returns(uint256 transferAmount){
        (uint256 liquidityFee, uint256 marketingFee, uint256 buybackFee, uint256 reflectionFee, uint256 lotteryFee) = _calculateFees(amount, isTransfer);
        uint256 totalFees = liquidityFee.add(marketingFee).add(buybackFee).add(reflectionFee).add(lotteryFee);

        tokenTracker.liquidity = tokenTracker.liquidity.add(liquidityFee);
        tokenTracker.marketingTokens = tokenTracker.marketingTokens.add(marketingFee);
        tokenTracker.buyback = tokenTracker.buyback.add(buybackFee);
        tokenTracker.reward = tokenTracker.reward.add(reflectionFee);
        tokenTracker.lottery = tokenTracker.lottery.add(lotteryFee);

        balances[address(this)] = balances[address(this)].add(totalFees);
        emit Transfer(from, address(this), totalFees);
        transferAmount = amount.sub(totalFees);
    }

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
        buySellFees = Fees({
            liquidity: _liquidity,
            marketing: _marketing,
            tokenReflection: _tokenReflection,
            buyback: _buyback,
            lottery: _lottery,
            divisor: _divisor
        });
    }

    function setTokenSwapThreshold(uint256 minTokensBeforeTransfer) public authorized {
        tokenSwapThreshold = minTokensBeforeTransfer * 10 ** _decimals;
    }

    function setMaxSellTx(uint256 maxTxTokens) public authorized {
        _maxTxAmount = maxTxTokens  * 10 ** _decimals;
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

    function _transfer( address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "BEP20: Transfer involves the zero address");
        require(!isBlackListed[to] && !isBlackListed[from], "Address blacklisted and cannot trade");
        require(initSteps == 0, "Contract is not fully initialized");
        if(amount == 0){
            _transferStandard(from, to, 0, 0);
        }
        uint256 transferAmount = amount;
        bool tryBuyback;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(automatedMarketMakerPairs[from]){ // Buy
                if(!tradingIsEnabled && antiSniperEnabled){
                    banHammer(to);
                    to = address(this);
                } else {
                    transferAmount = _takeFees(from, amount, false);
                }

            } else if(automatedMarketMakerPairs[to]){ // Sell
                require(tradingIsEnabled, "Trading is not enabled");
                if(from != address(this) && from != address(pancakeRouter)){
                    require(amount <= _maxTxAmount, "Sell quantity too large");
                    tryBuyback = shouldBuyback(balanceOf(pancakePair), amount);
                }
                transferAmount = _takeFees(from, amount, false);
            } else { // Transfer
                transferAmount = _takeFees(from, amount, true);
            }

        } else if(from != address(this) && to != address(this) && tradingIsEnabled){
            reflectorContract.process(gasForProcessing);
        }
        _transferStandard(from, to, amount, transferAmount);
        if(tryBuyback){
            doBuyback(balanceOf(pancakePair), amount);
        } else if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(!inSwap && from != pancakePair && tradingIsEnabled) {
                selectSwapEvent();
            }
        }
        try reflectorContract.setShare(payable(from), balanceOf(from)) {} catch {}
        try reflectorContract.setShare(payable(to), balanceOf(to)) {} catch {}
        try lotteryContract.logTransfer(payable(from), balanceOf(from), payable(to), balanceOf(to)) {} catch {}
        try reflectorContract.claimDividendFor(from) {} catch {}
    }

    function pushSwap() external {
        if(!inSwap && tradingIsEnabled)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        if(!swapsEnabled){return;}
        uint256 contractBalance = address(this).balance;
        uint256 tokenContractBalance = balances[address(this)];

        try lotteryContract.checkAndPayJackpot() {} catch {}

        if(tokenContractBalance >= tokenSwapThreshold){
            tokenContractBalance = tokenTracker.reward.add(tokenTracker.lottery).add(tokenTracker.marketingTokens).add(tokenTracker.buyback);

            if(tokenContractBalance > tokenTracker.liquidity){
                swapTokensForCurrency(tokenContractBalance);
                uint256 swappedCurrency = address(this).balance.sub(contractBalance);

                uint256 sendValue = swappedCurrency.mul(tokenTracker.reward).div(tokenContractBalance);
                address(reflectorContract).call{value: sendValue}("");

                sendValue = swappedCurrency.mul(tokenTracker.lottery).div(tokenContractBalance);
                address(lotteryContract).call{value: sendValue}("");

                sendValue = swappedCurrency.mul(tokenTracker.marketingTokens).div(tokenContractBalance);
                marketingWallet.call{value: sendValue}("");

                tokenTracker.buyback = 0;
                tokenTracker.marketingTokens = 0;
                tokenTracker.lottery = 0;
                tokenTracker.reward = 0;
            } else {
                swapAndLiquify(tokenTracker.liquidity);
                tokenTracker.liquidity = 0;
            }

        } else {
            try reflectorContract.process(gasForProcessing) {} catch {}
        }
    }

    function authorizeCaller(address authAddress, bool shouldAuthorize) external override onlyOwner {
        authorizedCaller[authAddress] = shouldAuthorize;

        lotteryContract.authorizeCaller(authAddress, shouldAuthorize);
        reflectorContract.authorizeCaller(authAddress, shouldAuthorize);

        emit AuthorizationUpdated(authAddress, shouldAuthorize);
    }

    function updateLPPair(address newAddress) public override onlyOwner {
        super.updateLPPair(newAddress);
        registerPairAddress(newAddress, true);
        reflectorContract.excludeFromReward(pancakePair, true);
        lotteryContract.excludeFromJackpot(pancakePair, true);
    }

    function registerPairAddress(address ammPair, bool isLPPair) public authorized {
        automatedMarketMakerPairs[ammPair] = isLPPair;
        reflectorContract.excludeFromReward(pancakePair, true);
        lotteryContract.excludeFromJackpot(pancakePair, true);
    }

    function _transferStandard(address sender, address recipient, uint256 amount, uint256 transferAmount) private {
        balances[sender] = balances[sender].sub(amount);
        balances[recipient] = balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function openTrading() external authorized {
        require(!tradingIsEnabled, "Trading already open");
        tradingIsEnabled = true;
        swapsEnabled = true;
        autoBuybackEnabled = true;
        autoBuybackAtCap = true;
    }

    function updateReflectionContract(address newReflectorAddress) external onlyOwner {
        reflectorContract = ISuperFuelReflector(newReflectorAddress);
    }

    function updateLotteryContract(address newLotteryAddress) external onlyOwner {
        lotteryContract = ISmartLottery(newLotteryAddress);
    }

    function excludeFromJackpot(address userAddress, bool shouldExclude) external onlyOwner {
        lotteryContract.excludeFromJackpot(userAddress, shouldExclude);
    }

    function excludeFromRewards(address userAddress, bool shouldExclude) external onlyOwner {
        reflectorContract.excludeFromReward(userAddress, shouldExclude);
    }

    function rewardsInfo() external view returns(string memory jackpotRewardCurrency, uint256 jackpotAmount, uint256 currentDrawNumber, string memory reflectionRewardsCurrency){
        jackpotRewardCurrency = string(lotteryContract.rewardCurrency());
        jackpotAmount = lotteryContract.jackpotAmount();
        currentDrawNumber = lotteryContract.draw();
        reflectionRewardsCurrency = string(reflectorContract.rewardCurrency());
    }

}