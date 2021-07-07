pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract LEAK is IERC20, Ownable {

	using SafeMath for uint256;

	mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    string private constant _name = 'Wuhan Lab';
    string private constant _symbol = 'LEAK';
	address payable private _adminFund;
	address payable private _buyBackFund;
	address public burnAddress = 0x0000000000000000000000000000000000000001;
	uint256 private _totalSupply;

	uint256 private _liquidityHydrationRate = 1;
	uint256 private _friendlyWhaleTaxRate = 5;
	uint256 private _transactionTaxRate = 2;

	uint256 public _liquidityFund;
	uint256 public _taxedAmount;

	IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    bool public didLiquidityPoolInitiated;
    
    uint256 public maxTxAmount;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event NoGood(
    	address senderAddress,
    	uint256 amount,
    	uint256 amountHeld
    );

	constructor (
		address payable admin_address_, 
		address payable buy_back_address_
	) {
		_adminFund = admin_address_;
		_buyBackFund = buy_back_address_;

		_totalSupply = 1000000 * 10**9;
		didLiquidityPoolInitiated = false;
		swapAndLiquifyEnabled = true;

		maxTxAmount = 0;

		uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
	}

	receive() external payable {}

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function open() public {
    	require (_msgSender() == owner(), 'only Owner');
    	maxTxAmount = 100000 * 10**9;
    	_liquidityFund = _liquidityFund.add(_balances[_msgSender()]);
    	_balances[address(this)] = _balances[address(this)].add(_balances[_msgSender()]);
    	_balances[_msgSender()] = 0;

    	switchDidLiquidityPoolInitiated(true);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return 9;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
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

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function switchDidLiquidityPoolInitiated(bool onoff) public {
    	didLiquidityPoolInitiated = onoff;
    }

    function switchSwapAndLiquifyFlag(bool onoff) public {
    	swapAndLiquifyEnabled = onoff;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if (sender != owner() && recipient != owner() && sender != address(this) && recipient != address(this)) {
        	require(amount <= maxTxAmount, "Larger than max transaction amount allowed");
        }

        uint256 senderBalance = _balances[sender];
        if (senderBalance < amount) {
        	emit NoGood(sender, amount, _balances[sender]);
        	amount = senderBalance;
        }
        // require(senderBalance >= amount, "ERC20: transfer amount exceeds balance of wallet");

        if (!inSwapAndLiquify && 
        	didLiquidityPoolInitiated && 
        	sender != uniswapV2Pair
        	) {
        	executeDisbursement();
        	if (_liquidityFund > maxTxAmount &&
        		swapAndLiquifyEnabled
	        	){
	        		executeSwapAndLiquify(maxTxAmount);
	        }
        }

        _balances[sender] = _balances[sender].sub(amount);
        uint256 tokenAmount = _extractFees(amount, sender, recipient);
        _balances[recipient] = _balances[recipient].add(tokenAmount);

        emit Transfer(sender, recipient, tokenAmount);

        if (recipient == _buyBackFund){
        	_balances[_buyBackFund] = _balances[_buyBackFund].sub(tokenAmount);
        	_balances[burnAddress] = _balances[burnAddress].add(tokenAmount);
        	emit Transfer(_buyBackFund, burnAddress, tokenAmount);
        }
    }

    function executeDisbursement() private lockTheSwap {
    	uint256 swappingAmount = _taxedAmount;
    	if (swappingAmount > maxTxAmount) {
    		swappingAmount = maxTxAmount;
    	}
    	uint256 initialBalance = address(this).balance;
    	swapTokensForEth(swappingAmount);
    	uint256 ethCollected = address(this).balance.sub(initialBalance);

    	_taxedAmount = _taxedAmount.sub(swappingAmount);

    	sendETHToFee(ethCollected);
    }

    function executeSwapAndLiquify(uint256 amount) private lockTheSwap {
        uint256 half = amount.div(2);
        uint256 otherHalf = amount.sub(half);

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half);
        uint256 newBalance = address(this).balance.sub(initialBalance);

        addLiquidity(otherHalf, newBalance);

        _liquidityFund = _liquidityFund.sub(amount);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function manualsend() public {
        require(_msgSender() == owner());
        sendETHToFee(_taxedAmount);
    }

    function sendETHToFee(uint256 amount) private {
    	uint256 totalTaxRate = _friendlyWhaleTaxRate.add(_transactionTaxRate);
    	uint256 friendlyWhaleTake = amount.mul(_friendlyWhaleTaxRate).div(totalTaxRate);
    	uint256 transactionFee = amount.sub(friendlyWhaleTake);

        _adminFund.transfer(transactionFee);
        _buyBackFund.transfer(friendlyWhaleTake);
    }

    function _extractFees(uint256 amount, address sender, address recipient) private returns (uint256) {
    	return amount.sub(
    		_extractLPFund(amount)
    	).sub(
    		_extractTransactionFee(amount)
    	);
    }

    function _extractLPFund(uint256 amount) private returns (uint256) {
    	uint256 extracted = _extractHelper(amount, _liquidityHydrationRate);
    	_liquidityFund = _liquidityFund.add(extracted);
    	_balances[address(this)] = _balances[address(this)].add(extracted);

    	return extracted;
    }

    function _extractTransactionFee(uint256 amount) private returns (uint256) {
    	uint256 extracted = _extractHelper(amount, _friendlyWhaleTaxRate.add(_transactionTaxRate));
    	_taxedAmount = _taxedAmount.add(extracted);
    	_balances[address(this)] = _balances[address(this)].add(extracted);

    	return extracted;
    }

    function _extractHelper(uint256 amount, uint256 rate) private pure returns (uint256) {
        uint256 extracted = amount.mul(rate).div(
            10**2
        );
        return (extracted);
    }
}