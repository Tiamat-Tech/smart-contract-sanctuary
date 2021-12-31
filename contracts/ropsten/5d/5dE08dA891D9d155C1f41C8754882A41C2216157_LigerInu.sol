// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import "./utils/LockableFunction.sol";
import "./utils/AntiLPSniper.sol";
import "./utils/LPSwapSupport.sol";
import "./interfaces/INoBSDynamicReflector.sol";

contract LigerInu is IBEP20, AntiLPSniper, LPSwapSupport {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    struct Fees{
        uint256 liquidity;
        uint256 marketing;
        uint256 tokenReflection;
        uint256 divisor;
    }

    struct TokenTracker{
        uint256 liquidity;
        uint256 marketingTokens;
        uint256 reward;
    }

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public _isExcludedFromFee;
    mapping (address => bool) public whitelist;
    mapping (address => bool) private automatedMarketMakerPairs;

    string private constant _name = "Liger Inu";
    string private constant _symbol = "LigerInu";
    uint256 private constant _decimals = 9;
    uint256 private  constant _totalSupply = 10 ** 14 * 10 ** _decimals;

    // Trackers for various pending token swaps and fees
    Fees public buyFees;
    Fees public sellFees;
    Fees public transferFees;
    TokenTracker public tokenTracker;

    uint256 public gasForProcessing = 400000;

    address public marketingWallet;
    INoBSDynamicReflector public reflectorContract;

    constructor (address _routerAddress, address tokenOwner, address _marketingWallet) payable {
        updateRouterAndPair(_routerAddress);
        balances[tokenOwner] = _totalSupply;

        marketingWallet = _marketingWallet;

        minTokenSpendAmount = _totalSupply.div(10 ** 5);

        buyFees = Fees({
            tokenReflection: 3,
            liquidity: 3,
            marketing: 3,
            divisor: 100
        });

        sellFees = Fees({
            tokenReflection: 3,
            liquidity: 3,
            marketing: 3,
            divisor: 100
        });

        transferFees = Fees({
            tokenReflection: 3,
            liquidity: 3,
            marketing: 3,
            divisor: 100
        });

        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingWallet] = true;
        _isExcludedFromFee[deadAddress] = true;

        _owner = tokenOwner;
        emit Transfer(address(0), _owner, balances[_owner]);
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

    function updateGasForProcessing(uint256 newValue) public authorized {
        require(newValue >= 200000 && newValue <= 1000000, "Gas requirement is between 200,000 and 1,000,000");
        require(newValue != gasForProcessing, "Gas requirement already set to that value");
        gasForProcessing = newValue;
    }

    function excludeFromFee(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromFee[account] = shouldExclude;
    }

    function _calculateFees(uint256 amount, Fees memory _fees) private pure returns(uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee) {
        liquidityFee = amount.mul(_fees.liquidity).div(_fees.divisor);
        marketingFee = amount.mul(_fees.marketing).div(_fees.divisor);
        reflectionFee = amount.mul(_fees.tokenReflection).div(_fees.divisor);
    }

    function _takeFees(address from, uint256 amount, Fees memory _fees) private returns(uint256 transferAmount){
        (uint256 liquidityFee, uint256 marketingFee, uint256 reflectionFee) = _calculateFees(amount, _fees);
        uint256 totalFees = liquidityFee.add(marketingFee).add(reflectionFee);

        tokenTracker.liquidity = tokenTracker.liquidity.add(liquidityFee);
        tokenTracker.marketingTokens = tokenTracker.marketingTokens.add(marketingFee);
        tokenTracker.reward = tokenTracker.reward.add(reflectionFee);

        balances[address(this)] = balances[address(this)].add(totalFees);
        emit Transfer(from, address(this), totalFees);
        transferAmount = amount.sub(totalFees);
    }

    function updateBuyFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee, uint256 newFeeDivisor) external onlyOwner {
        buyFees = Fees({
            tokenReflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateSellFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee, uint256 newFeeDivisor) external onlyOwner {
        sellFees = Fees({
            tokenReflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateTransferFees(uint256 reflectionFee, uint256 liquidityFee, uint256 marketingFee, uint256 newFeeDivisor) external onlyOwner {
        transferFees = Fees({
            tokenReflection: reflectionFee,
            liquidity: liquidityFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0) && spender != address(0), "BEP20: Approve involves the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "BEP20: Transfer involves the zero address");
        if(amount == 0){
            _transferStandard(from, to, 0, 0);
        }
        uint256 transferAmount = amount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            require(!isBlackListed[to] && !isBlackListed[from], "Address blacklisted and cannot trade");

            if(!tradingOpen && !whitelist[to]) {
                if(from == pancakePair && antiSniperEnabled){
                    banHammer(to);
                    to = address(this);
                    _transferStandard(from, to, amount, amount);
                    tokenTracker.liquidity = tokenTracker.liquidity.add(amount);
                    return;

                } else {
                    require(tradingOpen, "Trading not open");
                }
            }

            if(automatedMarketMakerPairs[from]){ // Buy
                transferAmount = _takeFees(from, amount, buyFees);
            } else if(automatedMarketMakerPairs[to]){ // Sell
                transferAmount = _takeFees(from, amount, sellFees);
            } else { // Transfer
                transferAmount = _takeFees(from, amount, transferFees);
            }

            if(!inSwap && from != pancakePair && from != address(pancakeRouter) && tradingOpen) {
                selectSwapEvent();
            }
        }

        _transferStandard(from, to, amount, transferAmount);
        reflectorContract.setShares(payable(from), balanceOf(from), payable(to), balanceOf(to));
    }

    function pushSwap() external {
        if(!inSwap && tradingOpen)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        if(!swapsEnabled){
            return;
        }
        TokenTracker memory _tokenTracker = tokenTracker;

        if(_tokenTracker.liquidity >= minTokenSpendAmount){
            uint256 contractTokenBalance = _tokenTracker.liquidity;
            swapAndLiquify(contractTokenBalance); // LP
            tokenTracker.liquidity = _tokenTracker.liquidity.sub(contractTokenBalance);

        } else if(_tokenTracker.marketingTokens >= minTokenSpendAmount){
            uint256 tokensSwapped = swapTokensForCurrencyAdv(address(this), _tokenTracker.marketingTokens, marketingWallet);
            tokenTracker.marketingTokens = _tokenTracker.marketingTokens.sub(tokensSwapped);
        }
        try reflectorContract.process(gasForProcessing) {} catch {}
    }

    function authorizeCaller(address authAddress, bool shouldAuthorize) external override onlyOwner {
        authorizedCaller[authAddress] = shouldAuthorize;
        reflectorContract.authorizeCaller(authAddress, shouldAuthorize);
        emit AuthorizationUpdated(authAddress, shouldAuthorize);
    }

    function updateLPPair(address newAddress) public override onlyOwner {
        super.updateLPPair(newAddress);
        if(address(reflectorContract) != address(0)){
            registerPairAddress(newAddress, true);
            reflectorContract.excludeFromReward(pancakePair, true);
        }
    }

    function registerPairAddress(address ammPair, bool isLPPair) public authorized {
        automatedMarketMakerPairs[ammPair] = isLPPair;
        reflectorContract.excludeFromReward(pancakePair, true);
    }

    function _transferStandard(address sender, address recipient, uint256 amount, uint256 transferAmount) private {
        balances[sender] = balances[sender].sub(amount);
        balances[recipient] = balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function openTrading() external override authorized {
        require(!tradingOpen, "Trading already enabled");
        tradingOpen = true;
        swapsEnabled = true;
    }

    function updateReflectionContract(address newReflectorAddress) external authorized {
        reflectorContract = INoBSDynamicReflector(newReflectorAddress);
    }

    function excludeFromRewards(address userAddress, bool shouldExclude) external onlyOwner {
        reflectorContract.excludeFromReward(userAddress, shouldExclude);
    }

    function reflections() external view returns(string memory){
        return reflectorContract.rewardCurrency();
    }

    function updateWhitelist(address wallet, bool shouldWhitelist) external onlyOwner {
        whitelist[wallet] = shouldWhitelist;
    }

    function batchUpdateWhitelist(address[] memory wallets, bool shouldWhitelist) external onlyOwner {
        uint256 addressCount = wallets.length;
        for(uint256 i = 0; i < addressCount; ++i){
            whitelist[wallets[i]] = shouldWhitelist;
        }
    }
}