// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

contract Vibra2 is Context, IERC20, Ownable {
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;

    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotalMil = 1000 * 1000;
    uint256 private _tTotal = _tTotalMil * (10**6) * (10**9);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Vibra V2";
    string private _symbol = "Vibra2";
    uint8 private _decimals = 9;

    uint256 public _taxFee = 4;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _burnFee = 2;
    uint256 private _previousBurnFee = _burnFee;


    uint256 public _liquidityFee = 3;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _marketWalletFee = 1;
    uint256 private _previousInvesterFee = _marketWalletFee;

    address private _marketWallet;
    address private _burnWallet;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 public _maxTxAmount = 10 * 10**9 * 10**9; // 1%
    uint256 private numTokensSellToAddToLiquidity = 10**9 * 10**9; // 0.1%

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor (address marketWalletAddress, address routerAddress, address burnAddress) {
        _rOwned[owner()] = _rTotal;

        _marketWallet = marketWalletAddress;
        _burnWallet = burnAddress;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;

        emit Transfer(address(0), owner(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) {
            return _tOwned[account];
        }
        return tokenFromReflection(_rOwned[account]);
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - (amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender]  + (addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] - (subtractedValue));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rTotal = _rTotal - (rAmount);
        _tFeeTotal = _tFeeTotal  + (tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount / (currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - (1)];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }

    function setMarketFeePercent(uint256 marketFeeInPercentage) external onlyOwner() {
        _marketWalletFee = marketFeeInPercentage;
    }

    function setBurnFeePercent(uint256 burnFeePercentage) external onlyOwner() {
        _burnFee = burnFeePercentage;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal * (maxTxPercent) / (10**2);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setNumTokensSellToAddToLiquidity(uint256 _numTokensSellToAddToLiquidity) public onlyOwner {
        numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;
    }

    // receive external payments
    receive() external payable {}

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / (tSupply);
    }

    struct Fees {
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tMarketing;
        uint256 tBurn;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, Fees memory) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tMarketing, uint256 tBurn) = _getTValues(tAmount);
        uint256 currentRate =  _getRate();
        Fees memory fees = Fees(tFee, tLiquidity, tMarketing, tBurn);
        (uint256 rAmount, uint256 rFee) = _getRBasics(tAmount, tFee, currentRate);
        uint256 rTransferAmount = _getRTransferAmount(rAmount, rFee, fees, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, fees);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tMarketing = calculateMarketFee(tAmount);
        uint256 tBurn = calculateBurnFee(tAmount);
        uint256 tTransferAmountA = tAmount - (tFee) - (tLiquidity);
        uint256 tTransferAmount = tTransferAmountA - (tMarketing) - (tBurn);
        return (tTransferAmount, tFee, tLiquidity, tMarketing, tBurn);
    }

    function _getRBasics(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount * (currentRate);
        uint256 rFee = tFee * (currentRate);
        return (rAmount, rFee);
    }

    function _getRTransferAmount(uint256 rAmount, uint256 rFee, Fees memory fees, uint256 currentRate) private pure returns (uint256) {
        uint256 rLiquidity = fees.tLiquidity * (currentRate);
        uint256 rMarketing = fees.tMarketing * (currentRate);
        uint256 rBurn = fees.tBurn * (currentRate);
        uint256 rTransferAmountA = rAmount - (rFee);
        uint256 rTransferAmount = rTransferAmountA - (rLiquidity) - (rMarketing) - (rBurn);
        return rTransferAmount;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) {
                return (_rTotal, _tTotal);
            }
            rSupply = rSupply - (_rOwned[_excluded[i]]);
            tSupply = tSupply - (_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal / (_tTotal)) {
            return (_rTotal, _tTotal);
        }
        return (rSupply, tSupply);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - (rFee);
        _tFeeTotal = _tFeeTotal  + (tFee);
    }

    function _takeLiquidity(uint256 tLiquidity, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity * (currentRate);
        _rOwned[address(this)] = _rOwned[address(this)]  + (rLiquidity);
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)]  + (tLiquidity);
        }
        emit Transfer(sender, address(this), tLiquidity);
    }

    function _sendToMarketing(uint256 tMarketing, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rMarketing = tMarketing * ((currentRate));

        _rOwned[_marketWallet] = _rOwned[_marketWallet]  + rMarketing;
        _tOwned[_marketWallet] = _tOwned[_marketWallet]  + tMarketing;
        emit Transfer(sender, _marketWallet, tMarketing);
    }

    function _burnTokens(uint256 tBurn, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rBurn = tBurn * ((currentRate));

        _rOwned[_burnWallet] = _rOwned[_burnWallet]  + rBurn;
        _tOwned[_burnWallet] = _tOwned[_burnWallet]  + tBurn;
        emit Transfer(sender, _burnWallet, tBurn);

    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_taxFee) / (10**2);
    }

    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_burnFee) / (10**2);
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_liquidityFee) / (10**2);
    }

    function calculateMarketFee(uint256 _amount) private view returns (uint256) {
        return _amount * (_marketWalletFee) / (10**2);
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 contractTokenBalance = balanceOf(address(this));

        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }

        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;

        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;

            swapAndLiquify(contractTokenBalance);
        }

        bool takeFee = true;

        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }

        _tokenTransfer(from,to,amount,takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / (2);
        uint256 otherHalf = contractTokenBalance - (half);

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForBNB(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - (initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForBNB(uint256 tokenAmount) private {

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(0),
            block.timestamp
        );
    }

    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee) {
            removeAllFee();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee) {
            restoreAllFee();
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rOwned[recipient] = _rOwned[recipient]  + (rTransferAmount);
        _takeLiquidity(fees.tLiquidity, sender);
        _sendToMarketing(fees.tMarketing, sender);
        _burnTokens(fees.tBurn, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _tOwned[recipient] = _tOwned[recipient]  + (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient]  + (rTransferAmount);
        _takeLiquidity(fees.tLiquidity, sender);
        _sendToMarketing(fees.tMarketing, sender);
        _burnTokens(fees.tBurn, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - (tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rOwned[recipient] = _rOwned[recipient]  + (rTransferAmount);
        _takeLiquidity(fees.tLiquidity, sender);
        _sendToMarketing(fees.tMarketing, sender);
        _burnTokens(fees.tBurn, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - (tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _tOwned[recipient] = _tOwned[recipient]  + (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient]  + (rTransferAmount);
        _takeLiquidity(fees.tLiquidity, sender);
        _sendToMarketing(fees.tMarketing, sender);
        _burnTokens(fees.tBurn, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _marketWalletFee == 0 && _burnFee == 0) {
            return;
        }

        _previousBurnFee = _burnFee;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousInvesterFee = _marketWalletFee;

        _burnFee = 0;
        _taxFee = 0;
        _liquidityFee = 0;
        _marketWalletFee = 0;
    }

    function restoreAllFee() private {
        _burnFee = _previousBurnFee;
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _marketWalletFee = _previousInvesterFee;
    }
}