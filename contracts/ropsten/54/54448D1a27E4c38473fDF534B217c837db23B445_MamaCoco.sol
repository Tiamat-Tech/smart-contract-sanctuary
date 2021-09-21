// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import "./utils/LPSwapSupport.sol";
import "./utils/LockableFunction.sol";
import "./utils/MamaCocoNoBSSupport.sol";
import "./utils/AntiLPSniper.sol";

contract MamaCoco is IBEP20, LockableFunction, MamaCocoNoBSSupport, LPSwapSupport, AntiLPSniper{
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 internal _totalSupply;

    string private _name;
    string private _symbol;
    uint256 internal _decimals;

    struct Fees{
        uint256 liquidity;
        uint256 marketing;
        uint256 development;
        uint256 charity;
        uint256 reflectionToken1;
        uint256 reflectionToken2;
        uint256 divisor;
    }

    struct TokenTracker{
        uint256 liquidity;
        uint256 marketing;
        uint256 development;
        uint256 charity;
        uint256 reflectionToken1;
        uint256 reflectionToken2;
    }

    Fees public buyFees;
    Fees public sellFees;
    Fees public transferFees;
    Fees public firstWeekSellFees;
    TokenTracker public taxAllocations;

    uint256 public tradingOpenedAt;
    uint256 public initialSellFeePeriod;

    address public marketingAddress = 0xf94ae1187D3572Ba64aE659C858DB200B7b65F2d;
    address public devAddress = 0xf94ae1187D3572Ba64aE659C858DB200B7b65F2d;
    address public charityAddress = 0xf94ae1187D3572Ba64aE659C858DB200B7b65F2d;

    uint256 public maxWalletSize;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    mapping (address => bool) public isExcludedFromFees;
    mapping (address => bool) private isWhitelisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping (address => bool) public automatedMarketMakerPairs;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event LiquidityWalletUpdated(address indexed newLiquidityWallet, address indexed oldLiquidityWallet);
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    constructor(string memory _NAME, string memory _SYMBOL, uint256 _DECIMALS, uint256 _supply, address routerAddress, address noBSRouterAddress,
            address tokenOwner) LPSwapSupport() NoBSAdvSupport(noBSRouterAddress) public {

        _name = _NAME;
        _symbol = _SYMBOL;
        _decimals = _DECIMALS;
        _totalSupply = _supply * 10 ** _decimals;

        updateRouter(routerAddress);

        transferFees.liquidity = 0;
        transferFees.marketing = 0;
        transferFees.development = 0;
        transferFees.charity = 0;
        transferFees.reflectionToken1 = 2;
        transferFees.reflectionToken2 = 8;
        transferFees.divisor = 100;

        buyFees.liquidity = 3;
        buyFees.marketing = 3;
        buyFees.development = 3;
        buyFees.charity = 1;
        buyFees.reflectionToken1 = 2;
        buyFees.reflectionToken2 = 3;
        buyFees.divisor = 100;

        sellFees.liquidity = 4;
        sellFees.marketing = 4;
        sellFees.development = 4;
        sellFees.charity = 1;
        sellFees.reflectionToken1 = 3;
        sellFees.reflectionToken2 = 4;
        sellFees.divisor = 100;

        firstWeekSellFees.liquidity = 3;
        firstWeekSellFees.marketing = 6;
        firstWeekSellFees.development = 3;
        firstWeekSellFees.charity = 6;
        firstWeekSellFees.reflectionToken1 = 3;
        firstWeekSellFees.reflectionToken2 = 9;
        firstWeekSellFees.divisor = 100;

        initialSellFeePeriod = 1 weeks;

        maxWalletSize = _totalSupply.div(100);
        minTokenSpendAmount = _totalSupply.div(100000);
        maxTokenSpendAmount = maxWalletSize;


        _balances[tokenOwner] = _totalSupply;
        emit Transfer(address(this), tokenOwner, _balances[tokenOwner]);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(tokenOwner, true);
        excludeFromFees(_owner, true);
        excludeFromFees(address(this), true);
    }

    function finalize() external onlyOwner init {
        updateRouterAndPair(address(pancakeRouter));
    }

    receive() external payable {}

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external override view returns (address) {
        return owner();
    }

    /**
     * @dev Returns the token name.
     */
    function name() public override view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() public override view returns (uint8) {
        return uint8(_decimals);
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) public override view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender) public override virtual view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override virtual returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), 'BEP20: approve from the zero address');
        require(spender != address(0), 'BEP20: approve to the zero address');

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev See {BEP20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override virtual returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, 'BEP20: decreased allowance below zero')
        );
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
            _allowances[sender][_msgSender()].sub(amount, 'BEP20: transfer amount exceeds allowance')
        );
        return true;
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for(uint256 i = 0; i < accounts.length; i++) {
            isExcludedFromFees[accounts[i]] = excluded;
        }

        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function updateLPPair(address newAddress) public override onlyOwner {
        super.updateLPPair(newAddress);

        automatedMarketMakerPairs[newAddress] = true;
        excludeFromRewards(newAddress, true);
    }

    function updateGasForProcessing(uint256 newValue) public onlyOwner {
        emit GasForProcessingUpdated(newValue, gasForProcessing);
        gasForProcessing = newValue;
    }

    function updateTransferFees(uint256 liquidityFee, uint256 marketingFee, uint256 devFee, uint256 charityFee, uint256 reflector1Fee, uint256 reflector2Fee, uint256 feeDivisor) external onlyOwner {
        transferFees = Fees({
            liquidity: liquidityFee,
            marketing: marketingFee,
            development: devFee,
            charity: charityFee,
            reflectionToken1: reflector1Fee,
            reflectionToken2: reflector2Fee,
            divisor: feeDivisor
        });
    }

    function updateSellFees(uint256 liquidityFee, uint256 marketingFee, uint256 devFee, uint256 charityFee, uint256 reflector1Fee, uint256 reflector2Fee, uint256 feeDivisor) external onlyOwner {
        _updateFees(true, liquidityFee, marketingFee, devFee, charityFee, reflector1Fee, reflector2Fee, feeDivisor);
    }

    function updateBuyFees(uint256 liquidityFee, uint256 marketingFee, uint256 devFee, uint256 charityFee, uint256 reflector1Fee, uint256 reflector2Fee, uint256 feeDivisor) external onlyOwner {
        _updateFees(false, liquidityFee, marketingFee, devFee, charityFee, reflector1Fee, reflector2Fee, feeDivisor);
    }

    function _updateFees(bool updateSellFee, uint256 _liquidity, uint256 _marketing, uint256 _dev, uint256 _charity, uint256 _reflector1, uint256 _reflector2, uint256 _divisor) private {
        if(updateSellFee){
            sellFees = Fees({
                liquidity: _liquidity,
                marketing: _marketing,
                development: _dev,
                charity: _charity,
                reflectionToken1: _reflector1,
                reflectionToken2: _reflector2,
                divisor: _divisor
            });
        } else {
            buyFees = Fees({
                liquidity: _liquidity,
                marketing: _marketing,
                development: _dev,
                charity: _charity,
                reflectionToken1: _reflector1,
                reflectionToken2: _reflector2,
                divisor: _divisor
            });
        }
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        uint256 tAmount = amount;
        if(amount == 0) {
            _simpleTransfer(from, to, 0, 0);
            return;
        }

        if(from != owner() && to != owner() && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            require(!isBlackListed[from] && !isBlackListed[to], "Address has been blacklisted");
            if(!isWhitelisted[from] && !isWhitelisted[to]) {
                if(automatedMarketMakerPairs[from] && antiSniperEnabled && !tradingIsEnabled){
                    banHammer(to);
                    to = address(this);
                } else {
                    require(tradingIsEnabled, "Cannot send tokens until trading is enabled");
                }
            }

            if(!inSwap && !automatedMarketMakerPairs[from]){
                performSwap();
            }

            tAmount = takeFees(from, amount, automatedMarketMakerPairs[to]);

            if(!automatedMarketMakerPairs[to]){
                require(balanceOf(to).add(tAmount) <= maxWalletSize, "Transfer would exceed wallet size restriction");
            }

            distributeRewards(gasForProcessing);

        }
        _simpleTransfer(from, to, amount, tAmount);
        updateReflectors(from, _balances[from], to, _balances[to]);
    }

    function _simpleTransfer(
        address sender,
        address recipient,
        uint256 amount,
        uint256 tAmount
    ) internal virtual {
        require(sender != address(0), 'BEP20: transfer from the zero address');
        require(recipient != address(0), 'BEP20: transfer to the zero address');

        _balances[sender] = _balances[sender].sub(amount, 'BEP20: transfer amount exceeds balance');
        _balances[recipient] = _balances[recipient].add(tAmount);
        emit Transfer(sender, recipient, tAmount);
    }

    function takeFees(address from, uint256 amount, bool isSell) private returns(uint256){
        Fees memory txFees;
        if(isSell){
            if(block.timestamp < tradingOpenedAt.add(initialSellFeePeriod)){
                txFees = firstWeekSellFees;
            } else {
                txFees = sellFees;
            }
        } else if(automatedMarketMakerPairs[from]){
            txFees = buyFees;
        } else {
            txFees = transferFees;
        }
        uint256 divisor = txFees.divisor;
        uint256 totalFees = 0;
        uint256 thisFee = 0;

        thisFee = amount.mul(txFees.liquidity).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.liquidity = taxAllocations.liquidity.add(thisFee);

        thisFee = amount.mul(txFees.marketing).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.marketing = taxAllocations.marketing.add(thisFee);

        thisFee = amount.mul(txFees.charity).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.charity = taxAllocations.charity.add(thisFee);

        thisFee = amount.mul(txFees.development).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.development = taxAllocations.development.add(thisFee);

        thisFee = amount.mul(txFees.reflectionToken1).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.reflectionToken1 = taxAllocations.reflectionToken1.add(thisFee);

        thisFee = amount.mul(txFees.reflectionToken2).div(divisor);
        totalFees = totalFees.add(thisFee);
        taxAllocations.reflectionToken2 = taxAllocations.reflectionToken2.add(thisFee);

        _balances[address(this)] = _balances[address(this)].add(totalFees);
        emit Transfer(from, address(this), totalFees);
        return amount.sub(totalFees);
    }

    function performSwap() private lockTheSwap {
        if(!swapsEnabled)
            return;
        if(taxAllocations.liquidity >= minTokenSpendAmount){
            swapAndLiquify(taxAllocations.liquidity);
            taxAllocations.liquidity = 0;
        } else {
            // Attempt all swaps, token limits in LPSwapSupport will return early if amount is too low
            taxAllocations.marketing = taxAllocations.marketing.sub(swapTokensForCurrencyAdv(address(this), taxAllocations.marketing, marketingAddress));
            taxAllocations.development = taxAllocations.development.sub(swapTokensForCurrencyAdv(address(this), taxAllocations.development, devAddress));
            taxAllocations.charity = taxAllocations.charity.sub(swapTokensForCurrencyAdv(address(this), taxAllocations.charity, charityAddress));
        }

        if(taxAllocations.reflectionToken1 >= minTokenSpendAmount){
            taxAllocations.reflectionToken1 = taxAllocations.reflectionToken1.sub(swapTokensForCurrencyAdv(address(this), taxAllocations.reflectionToken1, address(this)));
            noBSReflectors[0].deposit{value: address(this).balance}();
        } else {
            taxAllocations.reflectionToken2 = taxAllocations.reflectionToken2.sub(swapTokensForCurrencyAdv(address(this), taxAllocations.reflectionToken2, address(this)));
            noBSReflectors[1].deposit{value: address(this).balance}();
        }
    }

    function updateMaxWalletSizeInTokens(uint256 amount) external onlyOwner {
        maxWalletSize = amount * 10 ** _decimals;
    }

    function updateMarketingAddress(address _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
    }

    function updateDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
    }

    function updateCharityAddress(address _charityAddress) external onlyOwner {
        charityAddress = _charityAddress;
    }

    function updateWhitelist(address user, bool shouldWhitelist) external onlyOwner {
        isWhitelisted[user] = shouldWhitelist;
    }

    function openTrading() external onlyOwner {
        require(!tradingIsEnabled, "Trading already open");
        tradingIsEnabled = true;
        tradingOpenedAt = block.timestamp;
        swapsEnabled = true;
    }
}