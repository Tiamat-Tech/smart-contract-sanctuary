// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import '@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';
import './utils/Ownable.sol';
import "./utils/LPSwapSupport.sol";

contract DogueVC is IBEP20, LPSwapSupport {
    using SafeMath for uint256;
    using Address for address;

    struct TokenTracker {
        uint256 liquidity;
        uint256 marketing;
        uint256 buyback;
    }

    struct Fees {
        uint256 reflection;
        uint256 liquidity;
        uint256 buyback;
        uint256 marketing;
        uint256 divisor;
    }

    Fees public fees;
    TokenTracker public tokenTracker;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _isExcludedFromFee;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    string public constant override name = "DogueVC";
    string public constant override symbol = "DOGUE";
    uint256 private _decimals = 9;

    bool public tradingOpen = false;

    address payable public _marketingWallet = payable(0xA56A765E18589152D8C45f77A8916c707bf1E884);
    address payable public _buybackWallet = payable(0x36f9C6a2f64221af091005ba1A4b3b2225342c2a);

    uint256 private numTokensSellToAddToLiquidity;
    uint256 private numTokensSellForBNB;

    constructor (uint256 _supply, address _routerAddress, address _tokenOwner) public payable {
        _tTotal = _supply * 10 ** _decimals;
        _rTotal = (MAX - (MAX % _tTotal));

        numTokensSellToAddToLiquidity = _tTotal.mul(4).div(100000);
        numTokensSellForBNB = _tTotal.mul(6).div(100000);

        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(_routerAddress);
        pancakePair = IPancakeFactory(_pancakeRouter.factory()).createPair(address(this), _pancakeRouter.WETH());
        pancakeRouter = _pancakeRouter;

        liquidityReceiver = deadAddress;

        _rOwned[_tokenOwner] = _rTotal;
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(_marketingWallet)] = true;
        _isExcludedFromFee[address(_buybackWallet)] = true;

        fees = Fees({
            reflection: 2,
            liquidity: 5,
            buyback: 1,
            marketing: 4,
            divisor: 100
        });

        tokenTracker = TokenTracker(0,0,0);

        _owner = _tokenOwner;
        emit Transfer(address(this), _tokenOwner, _tTotal);
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function decimals() external view override returns(uint8){
        return uint8(_decimals);
    }

    function balanceOf(address account) public view override returns (uint256) {
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

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function getOwner() external view override returns (address) {
        return owner();
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromFee(address account, bool exclude) public onlyOwner {
        _isExcludedFromFee[account] = exclude;
    }

    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity) internal returns(uint256 rLiquidity) {
        if(tLiquidity == 0)
            return 0;
        uint256 currentRate =  _getRate();
        rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        tokenTracker.liquidity = tokenTracker.liquidity.add(tLiquidity);
        return rLiquidity;
    }

    function _takeBNBFees(uint256 tMarketing, uint256 tBuyback) private returns(uint256) {
        uint256 currentRate =  _getRate();
        uint256 rMarketing;
        uint256 rBuyback;
        if(tMarketing > 0){
            rMarketing = tMarketing.mul(currentRate);
            _rOwned[address(this)] = _rOwned[address(this)].add(rMarketing);
            tokenTracker.marketing = tokenTracker.marketing.add(tMarketing);
        }
        if(tBuyback > 0){
            rBuyback = tBuyback.mul(currentRate);
            _rOwned[address(this)] = _rOwned[address(this)].add(rBuyback);
            tokenTracker.buyback = tokenTracker.buyback.add(tBuyback);
        }
        return rBuyback.add(rMarketing);
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // This function was so large given the fee structure it had to be subdivided as solidity did not support
    // the possibility of containing so many local variables in a single execution.
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 rAmount;
        uint256 tTransferAmount;
        uint256 rTransferAmount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(!inSwap && from != pancakePair) {
                selectSwapEvent();
            }
            (rAmount, tTransferAmount, rTransferAmount) = takeFees(amount);
        } else {
            rAmount = amount.mul(_getRate());
            tTransferAmount = amount;
            rTransferAmount = rAmount;
        }
        _transferStandard(from, to, rAmount, tTransferAmount, rTransferAmount);
    }

    function pushSwap() external {
        if(!inSwap && tradingOpen)
            selectSwapEvent();
    }

    function selectSwapEvent() private lockTheSwap {
        uint256 marketing = tokenTracker.marketing;
        uint256 buyback = tokenTracker.buyback;
        uint256 liq = tokenTracker.liquidity;

        if(liq >= numTokensSellToAddToLiquidity){
            swapAndLiquify(liq);
            tokenTracker.liquidity = 0;
        } else if(marketing.add(buyback) >= numTokensSellForBNB){

            swapTokensForCurrency(buyback.add(marketing));
            uint256 forMarketing = address(this).balance.mul(fees.marketing).div(fees.buyback.add(fees.marketing));
            _marketingWallet.call{value: forMarketing}("");
            _buybackWallet.call{value: address(this).balance}("");

            tokenTracker.marketing = 0;
            tokenTracker.buyback = 0;
        }
    }

    function takeFees(uint256 amount) private returns(uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount){
        require(tradingOpen, "Trading not yet enabled.");
        uint256 currentRate = _getRate();
        uint256 tFee = amount.mul(fees.reflection).div(fees.divisor);
        uint256 rFee = tFee.mul(currentRate);

        uint256 tLiquidity = amount.mul(fees.liquidity).div(fees.divisor);
        uint256 tMarketing = amount.mul(fees.marketing).div(fees.divisor);
        uint256 tBuyback = amount.mul(fees.buyback).div(fees.divisor);

        uint256 rOther = _takeBNBFees(tMarketing, tBuyback);
        uint256 rLiquidity = _takeLiquidity(tLiquidity);

        tTransferAmount = amount.sub(tFee).sub(tMarketing);
        tTransferAmount = tTransferAmount.sub(tBuyback).sub(tLiquidity);
        rAmount = amount.mul(currentRate);
        rTransferAmount = rAmount.sub(rLiquidity).sub(rOther);
        _reflectFee(rFee, tFee);

        return (rAmount, tTransferAmount, rTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
        if(tTransferAmount == 0) { return; }
        if(sender != address(0))
            _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function updateFees(uint256 reflectionFee, uint256 liquidityFee, uint256 buybackFee, uint256 marketingFee, uint256 newFeeDivisor) public onlyOwner {
        fees = Fees({
            reflection: reflectionFee,
            liquidity: liquidityFee,
            buyback: buybackFee,
            marketing: marketingFee,
            divisor: newFeeDivisor
        });
    }

    function updateBuybackWallet(address buyback) external onlyOwner {
        _buybackWallet = payable(buyback);
    }

    function updateMarketingWallet(address marketing) external onlyOwner {
        _marketingWallet = payable(marketing);
    }

    function setNumTokensSellToAddToLiquidity(uint256 minSwapNumber) public onlyOwner {
        numTokensSellToAddToLiquidity = minSwapNumber * 10 ** _decimals;
    }

    function setNumTokensSellForBNB(uint256 minSwapNumber) public onlyOwner {
        numTokensSellForBNB = minSwapNumber * 10 ** _decimals;
    }

    function openTrading() external onlyOwner {
        require(tradingOpen == false, "Trading already enabled");
        tradingOpen = true;
        swapsEnabled = true;
    }
}