// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//-------------------------|| UnityFund.finance ||----------------------------\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\/\/\/\\//\\//\\//\\//\\//\\//\\/\/\/\/\/\/\/\/\/\/\\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

import '../libraries/IERC20.sol';
import '../libraries/SafeMath.sol';
import '../libraries/Context.sol';
import '../libraries/Address.sol';
import '../libraries/Ownable.sol';

import '../libraries/IUniswapV2Factory.sol';
import '../libraries/IUniswapV2Pair.sol';
import '../libraries/IUniswapV2Router01.sol';
import '../libraries/IUniswapV2Router02.sol';

contract UnityFundToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;

    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    address payable private _charityWalletAddress = payable(0x8B99F3660622e21f2910ECCA7fBe51d654a1517D);
    uint256 public _tDonationTotal;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotalMil = 1000;
    uint256 private _tTotal = _tTotalMil.mul(10**6).mul(10**9);
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint private _tDevTotal;

    string private _name = "TTV4";
    string private _symbol = "TTV4";
    uint8 private _decimals = 9;
    
    uint256 public _taxFee = 40; 
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _charityFee = 10;
    uint256 private _previousCharityFee = _charityFee;

    uint256 public _liquidityFee = 45;
    uint256 private _previousLiquidityFee = _liquidityFee;

    uint256 public _devFee = 5; 
    uint256 private _previousDevFee = _devFee;
    address private _devTeam;
    address private _adminTeam;
    address private _opTeam;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public _maxTxAmount = 10 * 10**6 * 10**9; // 1%
    uint256 private numTokensSellToAddToLiquidity = 1 * 10**6 * 10**9 / 10; // 0.01%
    
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
    
    constructor (address devAddr, address adminAddr, address opAddr, address routerAddress) {

        _rOwned[owner()] = _rTotal;

        _devTeam = devAddr;
        _adminTeam = adminAddr;
        _opTeam = opAddr;
        
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function totalDev() public view returns (uint256) {
        return _tDevTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
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
        return rAmount.div(currentRate);
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
                _excluded[i] = _excluded[_excluded.length.sub(1)];
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

    function setCharityFeePercent(uint256 charityFee) external onlyOwner() {
        _charityFee = charityFee;
    }
    
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner() {
        _liquidityFee = liquidityFee;
    }

    function setDevFeePercent(uint256 devFee) external onlyOwner() {
        _devFee = devFee;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
    // receive external payments
    receive() external payable {}

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    struct Fees {
        uint256 tFee; 
        uint256 tLiquidity; 
        uint256 tCharity; 
        uint256 tDev;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, Fees memory) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity, uint256 tCharity, uint256 tDev) = _getTValues(tAmount);
        uint256 currentRate =  _getRate();
        Fees memory fees = Fees(tFee, tLiquidity, tCharity, tDev);
        (uint256 rAmount, uint256 rFee) = _getRBasics(tAmount, tFee, currentRate);
        uint256 rTransferAmount = _getRTransferAmount(rAmount, rFee, fees, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, fees);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tCharity = calculateCharityFee(tAmount);
        uint256 tDev = calculateDevFee(tAmount);
        uint256 tTransferAmountA = tAmount.sub(tFee).sub(tLiquidity);
        uint256 tTransferAmount = tTransferAmountA.sub(tCharity).sub(tDev);
        return (tTransferAmount, tFee, tLiquidity, tCharity, tDev);
    }

    function _getRBasics(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        return (rAmount, rFee);
    }

    function _getRTransferAmount(uint256 rAmount, uint256 rFee, Fees memory fees, uint256 currentRate) private pure returns (uint256) {
        uint256 rCharity = fees.tCharity.mul(currentRate);
        uint256 rLiquidity = fees.tLiquidity.mul(currentRate);
        uint256 rDev = fees.tDev.mul(currentRate);
        uint256 rTransferAmountA = rAmount.sub(rFee).sub(rCharity);
        uint256 rTransferAmount = rTransferAmountA.sub(rLiquidity).sub(rDev);
        return rTransferAmount;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) {
                return (_rTotal, _tTotal);
            }
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) {
            return (_rTotal, _tTotal);
        }
        return (rSupply, tSupply);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }
    
    function _takeLiquidity(uint256 tLiquidity, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        }
        emit Transfer(sender, address(this), tLiquidity);
    }
    
    function _takeCharity(uint256 tCharity, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[_charityWalletAddress] = _rOwned[_charityWalletAddress].add(rCharity);
        if(_isExcluded[_charityWalletAddress]) {
            _tOwned[_charityWalletAddress] = _tOwned[_charityWalletAddress].add(tCharity);
        }
        emit Transfer(sender, _charityWalletAddress, tCharity);
    }

    function _sendToDev(uint256 tDev, address sender) private {
        uint256 currentRate = _getRate();
        uint256 rDev = tDev.mul((currentRate));
        uint256 tVal = tDev.div(3);
        uint  rVal = rDev.div(3);

        _rOwned[_devTeam] = _rOwned[_devTeam].add(rVal);
        _tOwned[_devTeam] = _tOwned[_devTeam].add(tVal);
        emit Transfer(sender, _devTeam, tVal);

        _rOwned[_adminTeam] = _rOwned[_adminTeam].add(rVal);
        _tOwned[_adminTeam] = _tOwned[_adminTeam].add(tVal);
        emit Transfer(sender, _adminTeam, tVal);

        _rOwned[_opTeam] = _rOwned[_opTeam].add(rVal);
        _tOwned[_opTeam] = _tOwned[_opTeam].add(tVal);
        emit Transfer(sender, _opTeam, tVal);
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**3); 
    }

    function calculateCharityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_charityFee).div(10**3);
    }

    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(10**3);
    }

    function calculateDevFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_devFee).div(10**3);
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
        if(from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

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
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = address(this).balance;

        swapTokensForEth(half); 

        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        
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
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(fees.tLiquidity, sender);
        _takeCharity(fees.tCharity, sender);
        _sendToDev(fees.tDev, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeLiquidity(fees.tLiquidity, sender);
        _takeCharity(fees.tCharity, sender);
        _sendToDev(fees.tDev, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeLiquidity(fees.tLiquidity, sender);
        _takeCharity(fees.tCharity, sender);
        _sendToDev(fees.tDev, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, Fees memory fees) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeLiquidity(fees.tLiquidity, sender);
        _takeCharity(fees.tCharity, sender);
        _sendToDev(fees.tDev, sender);
        _reflectFee(rFee, fees.tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0 && _charityFee == 0 && _devFee == 0) {
            return;
        }
        
        _previousTaxFee = _taxFee;
        _previousCharityFee = _charityFee;
        _previousLiquidityFee = _liquidityFee;
        _previousDevFee = _devFee;
        
        _taxFee = 0;
        _charityFee = 0;
        _liquidityFee = 0;
        _devFee = 0;
    }
    
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _charityFee = _previousCharityFee;
        _liquidityFee = _previousLiquidityFee;
        _devFee = _previousDevFee;
    }

}