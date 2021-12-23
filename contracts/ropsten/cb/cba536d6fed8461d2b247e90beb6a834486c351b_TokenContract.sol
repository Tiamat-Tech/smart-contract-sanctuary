/**
 *Submitted for verification at Etherscan.io on 2021-12-23
*/

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.9;

/**
 * BEP20 standard interface
 */

interface IBEP20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * Basic access control mechanism
 */

abstract contract Ownable {
    address internal owner;
    address private _previousOwner;
    uint256 private _lockTime;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function getUnlockTime() public view returns (uint256) {
        return _lockTime;
    }

    function Ownershiplock(uint256 time) public virtual onlyOwner {
        _previousOwner = owner;
        owner = address(0);
        _lockTime = block.timestamp + time;
        emit OwnershipTransferred(owner, address(0));
    }

    function Ownershipunlock() public virtual {
        require(_previousOwner == msg.sender, "You don't have permission to unlock");
        require(block.timestamp > _lockTime , "Contract is locked until 7 days");
        emit OwnershipTransferred(owner, _previousOwner);
        owner = _previousOwner;
    }
}

/**
 * Router Interfaces
 */

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

/**
 * Contract Code
 */

contract TokenContract is IBEP20, Ownable {
        
    // Events
    event AutoLiquify(uint256 amountBNB, uint256 amountTokens);
    event SetSwapBackSettings(bool enabled, uint256 swapThreshold);
    event SetFeeReceivers(address marketingReceiver);
    event StuckBalanceSent(uint256 amountBNB, address recipient);
    event ForeignTokenTransfer(address tokenAddress, uint256 quantity);
    event ExcludeFromFee(address Address, bool Excluded);
    event GasLimitSet(uint256 gas);
    event SetProtectionSettings(bool antiGas, bool sameBlock, bool sniperProtection);
    event SetBuyFee(uint256 liquidityFee, uint256 marketingFee, uint256 reflectFee);
    event SetSellFee(uint256 liquidityFee, uint256 marketingFee, uint256 reflectFee);
    event SetMaxWallet(uint256 maxWallet);
    event SetMaxTX(uint256 maxTX);
    event SetOperator(address newOperator);
    event SniperCaught(address sniperAddress);
    event RemovedSniper(address notsniper);

    // Mappings
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) public isSniper;
    mapping(address => uint256) private lastTrade;

    // Supply    
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    
    // Basic Contract Info
    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 9;

    IDEXRouter public router;
    address public pair;

    // Transaction Limits
    uint256 private _maxTxAmount;
    uint256 private _maxWalletSize;

    // Detailed Fees
    struct BuyFee {
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 taxFee;
    }

    struct SellFee {
        uint16 liquidityFee;
        uint16 marketingFee;
        uint16 taxFee;
    }

    BuyFee public buyFee;
    SellFee public sellFee;

    uint16 private _taxFee;
    uint16 private _liquidityFee;
    uint16 private _marketingFee;
    uint256 private _tFeeTotal;  
    
    // Operator Function
    address public operator;
    modifier onlyOperator() {
        require(msg.sender == operator);
        _;
    }

    // Fee Receiver
    address private marketingFeeReceiver = 0x534C3f654Ad197C3AD4CBee7daAB416fA2e9Df0B; // Marketing Address

    // AntiBot Functions
    bool public sniperProtection;
    bool public sameBlockActive;
    bool public gasLimitActive;

    uint256 public tradingActiveBlock;
    uint256 public snipeBlocks = 2;
        
    uint256 private gasPriceLimit = 150 * 1 gwei;

    uint256 public launchedAt;

    // SwapBack (Marketing + Liquidity)
    bool inSwap;
    bool public swapEnabled = true;
    uint256 public swapThreshold;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }
    
    constructor () Ownable(msg.sender) {
        buyFee.liquidityFee = 1;
        buyFee.marketingFee = 2;
        buyFee.taxFee = 2;

        sellFee.liquidityFee = 3;
        sellFee.marketingFee = 3;
        sellFee.taxFee = 3;

        _isExcludedFromFee[owner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingFeeReceiver] = true;
    }

    function name() external view override returns (string memory) { return _name; }
    function symbol() external view override returns (string memory) { return _symbol; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function getOwner() external view override returns (address) { return owner; }
    function totalSupply() external view override returns (uint256) { return _tTotal; }
    function balanceOf(address account) public view returns (uint256) { return tokenFromReflection(_rOwned[account]);}

    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender]-(amount));
        return true;
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount / (currentRate);
    }

    receive() external payable {}

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function initialize() external onlyOwner {
        _tTotal = 1 * 10 ** 9 * (10**_decimals);
        _rTotal = (MAX - (MAX % _tTotal));

        _name = "FUCK UNKNOWN SNIPERS";
        _symbol = "FUS";

        _maxTxAmount = _tTotal / 100 * 1;
        _maxWalletSize = _tTotal / 100 * 1;
        swapThreshold = _tTotal / 1000 * 1; // 0.1%

        router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
        _allowances[address(this)][address(router)] = type(uint256).max;

        _rOwned[address(this)] = _rTotal;
        emit Transfer(address(0), address(this), _tTotal);

        _transfer(address(this), owner, _tTotal / 100 * 1);

        router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner,
            block.timestamp
        );

    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        if(!launched() && recipient == pair){
            require(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient], "Trading is not active yet.");
            launch();
        }

        if (gasLimitActive) {
            require(tx.gasprice <= gasPriceLimit, "Gas price exceeds limit.");
        }
   
        if(sender != owner
            && recipient != owner
            && recipient != address(0)
            && sender != address(this)) {

            if (sameBlockActive) {
                if (sender == pair){
                    require(lastTrade[recipient] != block.number);
                    lastTrade[recipient] = block.number;
                } else {
                    require(lastTrade[sender] != block.number);
                    lastTrade[sender] = block.number;
                }
            }

            if (block.number - tradingActiveBlock > snipeBlocks){
                require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

                if(recipient != pair) {
                    require(balanceOf(recipient) + amount <= _maxWalletSize, "Transfer amount exceeds the maxWalletSize.");
                }
            }
        }

        bool takeFee = true;

        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            takeFee = false;
        } else {
            // Buy
            if (sender == pair) {
                removeAllFee();
                setBuy();                
            } 
            // Sell
            else if (recipient == pair) {
                removeAllFee();
                setSell();
                }
            // Transfers dont get taxed
            else {
                removeAllFee();
            }
        }

        if(shouldSwapBack(sender, recipient)){ swapBack(); }

        _tokenTransfer(sender, recipient, amount);
        
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount) private {
        if (sniperProtection){
            // If sender is a sniper address, reject the transfer.
            if (isSniper[sender] || isSniper[recipient]) {
                revert("Sniper rejected.");
            }

            if (tradingActiveBlock > 0 
                    && sender == pair
                    && sender != owner
                    && recipient != owner
                    && recipient != address(0)
                    && sender != address(this)) {
                    if (block.number - tradingActiveBlock < snipeBlocks) {
                        isSniper[recipient] = true;
                        emit SniperCaught(recipient);
                    }
                }
            }

        _transferStandard(sender, recipient, amount);
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        _takeFees(tLiquidity, tMarketing, rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeFees(uint256 tLiquidity, uint256 tMarketing, uint256 rFee, uint256 tFee) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity * (currentRate);
        uint256 rMarketing = tMarketing * (currentRate);
        _rOwned[address(this)] = _rOwned[address(this)] + (rLiquidity) + (rMarketing);
        _rTotal = _rTotal - (rFee);
        _tFeeTotal = _tFeeTotal + (tFee);
    }
    
    function setBuy() private {
        _taxFee = buyFee.taxFee;
        _liquidityFee = buyFee.liquidityFee;
        _marketingFee = buyFee.marketingFee;
    }

    function setSell() private {
        _taxFee = sellFee.taxFee;
        _liquidityFee = sellFee.liquidityFee;
        _marketingFee = sellFee.marketingFee;
    }

    function launched() internal view returns (bool) {
        return launchedAt != 0;
    }

    function launch() internal {
        launchedAt = block.timestamp;
        tradingActiveBlock = block.number;
        sniperProtection = true;
        gasLimitActive = true;
        sameBlockActive = true;
    }

    function shouldSwapBack(address sender, address recipient) internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && !_isExcludedFromFee[recipient]
        && !_isExcludedFromFee[sender]
        && recipient == pair
        && balanceOf(address(this)) >= swapThreshold;
    }

    function swapBack() internal swapping {       
        uint256 totalFee = _marketingFee + _liquidityFee;
        uint256 contractTokenBalance = balanceOf(address(this));

        uint256 amountToLiquify = contractTokenBalance * _liquidityFee / totalFee / (2);
        uint256 amountToSwap = contractTokenBalance - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint256 amountBNB = address(this).balance;
        uint256 totalBNBFee = totalFee - (_liquidityFee / (2));
        uint256 amountBNBLiquidity = amountBNB * _liquidityFee / totalBNBFee / (2);
        uint256 amountBNBMarketing = amountBNB - amountBNBLiquidity;

        if(amountBNBMarketing > 0) {payable(marketingFeeReceiver).transfer(amountBNBMarketing);
        }

        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountBNBLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                marketingFeeReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountBNBLiquidity, amountToLiquify);
        }
    }

    // Reflections code
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing) = _calculateTokenValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _calculateRateValues(tAmount, tFee, tLiquidity, tMarketing, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tLiquidity, tMarketing);
    }

    function _calculateTokenValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = tAmount * (_taxFee) / (10**2);
        uint256 tLiquidity = tAmount * (_liquidityFee) / (10**2);
        uint256 tMarketing = tAmount * (_marketingFee) / (10**2);
        uint256 tTransferAmount = tAmount - (tFee) - (tLiquidity) - (tMarketing);
        return (tTransferAmount, tFee, tLiquidity, tMarketing);
    }

    function _calculateRateValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * (currentRate);
        uint256 rFee = tFee * (currentRate);
        uint256 rLiquidity = tLiquidity * (currentRate);
        uint256 rMarketing = tMarketing * (currentRate);
        uint256 rTransferAmount = rAmount - (rFee) - (rLiquidity) - (rMarketing);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / (tSupply);
    }
    
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        if (rSupply < _rTotal / (_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0 && _marketingFee == 0) return;

        _taxFee = 0;
        _liquidityFee = 0;
        _marketingFee = 0;
    }

    // External Functions
    function excludeFromFee(address account, bool exempt) external onlyOwner {
        _isExcludedFromFee[account] = exempt;
        emit ExcludeFromFee(account, exempt);
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
        emit SetOperator(_operator);
    }
   
    function setSwapBackSettings(bool _enabled, uint256 _swapThreshold) external onlyOwner {
        swapEnabled = _enabled;
        swapThreshold = _swapThreshold;
        emit SetSwapBackSettings(_enabled, swapThreshold);
    }

    function setFeeReceiver(address _marketingFeeReceiver) external onlyOwner {
        marketingFeeReceiver = _marketingFeeReceiver;
        emit SetFeeReceivers(marketingFeeReceiver);
    }

    function setBuyFees(uint16 liq, uint16 market, uint16 tax) external onlyOperator {
        require(liq + market + tax <= 30, "Total fees must be below 30%");
        buyFee.liquidityFee = liq;
        buyFee.marketingFee = market;
        buyFee.taxFee = tax;
        emit SetBuyFee(liq,market,tax);
    }

    function setSellFees(uint16 liq, uint16 market, uint16 tax) external onlyOperator {
        require(liq + market + tax <= 30, "Total fees must be below 30%");
        sellFee.liquidityFee = liq;
        sellFee.marketingFee = market;
        sellFee.taxFee = tax;
        emit SetSellFee(liq,market,tax);
    }
     
    function removeSniper(address account) external onlyOwner {
        isSniper[account] = false;
        emit RemovedSniper(account);
    }

    function setProtectionSettings(bool antiGas, bool sameBlock, bool sniperProtect) external onlyOwner() {
        gasLimitActive = antiGas;
        sameBlockActive = sameBlock;
        sniperProtection = sniperProtect;
        emit SetProtectionSettings(antiGas, sameBlock, sniperProtect);
    }
    
    function setGasPriceLimit(uint256 gas) external onlyOwner {
        require(gas >= 75);
        gasPriceLimit = gas * 1 gwei;
        emit GasLimitSet(gas);
    }

    function setMaxWallet(uint256 _maxWallet) external onlyOwner {
        require(_maxWallet * 10 **_decimals > _tTotal / 500 &&
                _maxWallet * 10 **_decimals < _tTotal / 50, "Can't set MaxWallet lower than 0.2% or higher than 2%");
        _maxWalletSize = _maxWallet * 10 **_decimals;
        emit SetMaxWallet(_maxWallet);
    }

    function setMaxTX(uint256 _maxTX) external onlyOwner {
        require(_maxTX * 10 **_decimals > _tTotal / 500 &&
                _maxTX * 10 **_decimals < _tTotal / 50, "Can't set TxLimit lower than 0.2% or higher than 2%");
        _maxTxAmount = _maxTX * 10 **_decimals;
        emit SetMaxTX(_maxTX);
    }


    // Stuck Balance Functions
    function ClearStuckBalance() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        payable(marketingFeeReceiver).transfer(contractBalance);
        emit StuckBalanceSent(contractBalance, marketingFeeReceiver);
    }

    function transferForeignToken(address _token) public onlyOwner {
        require(_token != address(this), "Can't let you take all native token");
        uint256 _contractBalance = IBEP20(_token).balanceOf(address(this));
        payable(marketingFeeReceiver).transfer(_contractBalance);
        emit ForeignTokenTransfer(_token, _contractBalance);
    }
}