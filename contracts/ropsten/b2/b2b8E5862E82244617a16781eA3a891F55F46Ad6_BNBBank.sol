// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
import "./utils/LPSwapSupport.sol";
import "./utils/DividendTracker.sol";

contract BNBBank is LPSwapSupport, BEP20 {
    using SafeMath for uint256;

    DividendTracker public dividendTracker;

    uint256 public swapTokensAtAmount;

    bool public tradingIsEnabled;

    uint256 public BNBRewardsFee;
    uint256 public BNBRewardsSellFee;

    uint256 public liquidityFee;
    uint256 public marketingFee;

    uint256 public totalFees;
    uint256 public totalSellFees;

    uint256 public tokensForLP;

    address payable public marketingAddress;
    uint256 public maxWalletSize;
    uint256 public sellThresholdForFeeIncrease;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private isBlacklisted;
    mapping (address => bool) private isWhitelisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event UpdateDividendTracker(address indexed newAddress, address indexed oldAddress);

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event SendDividends(
        uint256 tokensSwapped,
        uint256 amount
    );

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor(string memory _NAME, string memory _SYMBOL, uint256 _DECIMALS, uint256 _supply, address routerAddress,
            address tokenOwner) public BEP20(_NAME, _SYMBOL) {
//        _owner = msg.sender;
        _decimals = _DECIMALS;
        _totalSupply = _supply * 10 ** _decimals;
        BNBRewardsFee = 14;
        BNBRewardsSellFee = 3;
        liquidityFee = 5;
        marketingFee = 5;

        swapTokensAtAmount = 2000000 * (10 ** _decimals);
        minSwapAmount = 0.05 ether;
        maxSwapAmount = 1 ether;


        totalFees = BNBRewardsFee.add(liquidityFee).add(marketingFee);
        totalSellFees = totalFees.add(BNBRewardsSellFee);
        liquidityReceiver = deadAddress;

        dividendTracker = new DividendTracker();

//        updateRouterAndPair(routerAddress);

        marketingAddress = payable(tokenOwner);

        // exclude from receiving dividends
        dividendTracker.excludeFromDividends(address(dividendTracker));
        dividendTracker.excludeFromDividends(address(this));
//        dividendTracker.excludeFromDividends(address(pancakeRouter));
//        dividendTracker.excludeFromDividends(address(pancakePair));

        _balances[tokenOwner] = _totalSupply;
//        try dividendTracker.setBalance(payable(tokenOwner), balanceOf(tokenOwner)) {} catch {}

        // exclude from paying fees or having max transaction amount
        excludeFromFees(tokenOwner, true);
        excludeFromFees(_owner, true);
        excludeFromFees(address(this), true);
//        _owner = tokenOwner;
    }

    receive() external payable {

    }

    // Override to disallow minting
    function _mint(address, uint256) internal override {
        require(1 == 0, "Minting is disabled for this contract");
    }

    function _approve(address owner, address spender, uint256 tokenAmount) internal override(LPSwapSupport, BEP20) {
        super._approve(owner, spender, tokenAmount);
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "The dividend tracker already has that address");

        DividendTracker newDividendTracker = DividendTracker(payable(newAddress));

        require(newDividendTracker.owner() == address(this), "The new dividend tracker must be owned by this token contract");

        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(address(pancakeRouter));
        newDividendTracker.excludeFromDividends(address(pancakePair));
        emit UpdateDividendTracker(newAddress, address(dividendTracker));

        dividendTracker = newDividendTracker;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        require(_isExcludedFromFees[account] != excluded, "Address is already set to this value");
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }
    function updateLPPair(address newAddress) public override onlyOwner {
        super.updateLPPair(newAddress);

        automatedMarketMakerPairs[newAddress] = true;
        dividendTracker.excludeFromDividends(newAddress);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        require(newValue >= 200000 && newValue <= 1000000, "Gas requirement is between 200,000 and 1,000,000");
        require(newValue != gasForProcessing, "Gas requirement already set to that value");
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateClaimWait(uint256 claimWait) external onlyOwner {
        dividendTracker.updateClaimWait(claimWait);
    }

    function getClaimWait() external view returns(uint256) {
        return dividendTracker.claimWait();
    }

    function getTotalDividendsDistributed() external view returns (uint256) {
        return dividendTracker.totalDividendsDistributed();
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawableDividendOf(address account) public view returns(uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function updateFees(uint256 _BNBRewardsFee, uint256 _aditionalBNBRewardsSellFee, uint256 _liquidityFee, uint256 _marketingFee) external onlyOwner {
        BNBRewardsFee = _BNBRewardsFee;
        BNBRewardsSellFee = _aditionalBNBRewardsSellFee;
        liquidityFee = _liquidityFee;
        marketingFee = _marketingFee;
        totalFees = marketingFee.add(liquidityFee).add(BNBRewardsFee);
        totalSellFees = totalFees.add(BNBRewardsSellFee);
    }

    function getAccountDividendsInfo(address account)
    external view returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256) {
        return dividendTracker.getAccount(account);
    }

    function getAccountDividendsInfoAtIndex(uint256 index)
    external view returns (
        address,
        int256,
        int256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256) {
        return dividendTracker.getAccountAtIndex(index);
    }

    function processDividendTracker(uint256 gas) external {
        (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) = dividendTracker.process(gas);
        emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, false, gas, tx.origin);
    }

    function claim() external {
        dividendTracker.processAccount(msg.sender, false);
    }

    function getLastProcessedIndex() external view returns(uint256) {
        return dividendTracker.getLastProcessedIndex();
    }

    function getNumberOfDividendTokenHolders() external view returns(uint256) {
        return dividendTracker.getNumberOfTokenHolders();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");

        if(amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if(from != owner() && to != owner() && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            require(!isBlacklisted[from] && !isBlacklisted[to], "Address has been blacklisted");
            if(!isWhitelisted[from] && !isWhitelisted[to])
                require(tradingIsEnabled, "Cannot send tokens until trading is enabled");
            bool didSwap = false;

            uint256 contractTokenBalance = balanceOf(address(this));
            if(!inSwap && !automatedMarketMakerPairs[from] && contractTokenBalance >= swapTokensAtAmount){
                performSwap();
                didSwap = true;
            }

            // Sell event
            if(automatedMarketMakerPairs[to]) {
                if(amount >= sellThresholdForFeeIncrease)
                    amount = takeFees(from, amount, true);
                else
                    amount = takeFees(from, amount, false);
            } else
            // Buy event
            if(automatedMarketMakerPairs[from]) {
                amount = takeFees(from, amount, false);
            } else
            // Regular transfer
            {
                amount = takeFees(from, amount, false);
            }
            if(!automatedMarketMakerPairs[to]){
                require(balanceOf(to).add(amount) <= maxWalletSize, "Transfer would exceed wallet size restriction");
            }

            super._transfer(from, to, amount);

            try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
            try dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {}

            if(!didSwap && !inSwap){
                _distributeRewards();
            }

        } else {
            super._transfer(from, to, amount);
            if(!inSwap){
                _distributeRewards();
            }
        }
    }

    function takeFees(address from, uint256 amount, bool isSell) private returns(uint256){
        uint256 forMarketing = amount.mul(marketingFee).div(100);
        uint256 forLP = amount.mul(liquidityFee).div(100);
        uint256 forRewards;
        if(isSell){
            forRewards = amount.mul(BNBRewardsFee.add(BNBRewardsSellFee)).div(100);
        } else {
            forRewards = amount.mul(BNBRewardsFee).div(100);
        }
        uint256 totalFeesTaken = forRewards.add(forLP).add(forMarketing);

        super._transfer(from, address(this), totalFeesTaken);
        super._transfer(address(this), marketingAddress, forMarketing);
        tokensForLP = tokensForLP.add(forLP);
        try dividendTracker.setBalance(payable(address(this)), balanceOf(address(this))) {} catch {}
        try dividendTracker.setBalance(marketingAddress, balanceOf(marketingAddress)) {} catch {}
        return amount.sub(totalFeesTaken);
    }

    function performSwap() private lockTheSwap {
        uint256 swapTokens = tokensForLP;
        swapAndLiquify(swapTokens);
        tokensForLP = 0;

        uint256 sellTokens = balanceOf(address(this));
        swapAndSendDividends(sellTokens);
    }
    function distributeRewards() public {
        if(!inSwap)
            _distributeRewards();
    }

    function _distributeRewards() private lockTheSwap {
        uint256 gas = gasForProcessing;

        try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
        }
        catch {}
    }

    function swapAndSendDividends(uint256 tokens) private {
        swapTokensForCurrency(tokens);
        uint256 dividends = address(this).balance;
        (bool success,) = address(dividendTracker).call{value: dividends}("");

        if(success) {
            emit SendDividends(tokens, dividends);
        }
    }

    function updateMaxWalletSizeInTokens(uint256 amount) external onlyOwner {
        maxWalletSize = amount * 10 ** _decimals;
    }

    function updateSellFeeIncreaseInTokens(uint256 amount) external onlyOwner {
        sellThresholdForFeeIncrease = amount * 10 ** _decimals;
    }

    function updateTokenSwapThreshold(uint256 amount) external onlyOwner {
        swapTokensAtAmount = amount * 10 ** _decimals;
    }

    function updateMarketingAddress(address payable _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
    }

    function updateWhitelist(address user, bool shouldWhitelist) external onlyOwner {
        isWhitelisted[user] = shouldWhitelist;
    }

    function updateBlacklist(address user, bool shouldBlacklist) external onlyOwner {
        isBlacklisted[user] = shouldBlacklist;
    }

    function openTrading() external onlyOwner {
        require(!tradingIsEnabled, "Trading already open");
        tradingIsEnabled = true;
    }
}