pragma solidity 0.8.0;

// import "openzeppelin-solidity/contracts/utils/Context.sol";
// import "openzeppelin-solidity/contracts/utils/Address.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract DynamicTaxCoin is IERC20, Ownable {

	using SafeMath for uint256;

	mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    string private constant _name = 'DynamicTaxCoin';
    string private constant _symbol = 'DTC';
	address payable private _admin;
	address payable private _revitalization_fund;
	uint256 private _totalSupply;

	uint8 private _liquidityFee = 1;
	uint8 private _tax = 1;

	uint256 private _liquidityFund;
	uint256 private _taxedAmount;
	uint256 private _revitalizationFundAmount;

	IUniswapV2Router02 private uniswapV2Router;
    address public uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;
    bool public didLiquidityPoolInitiated;
    
    uint256 public maxTxAmount;
    // uint256 private _numTokensSellToAddToLiquidity;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

	constructor (
		address payable admin_address_, 
		address payable revitalization_fund_
	) {
		_admin = admin_address_;
		_revitalization_fund = revitalization_fund_;

		_totalSupply = 1000000 * 10**9;
		didLiquidityPoolInitiated = false;

		maxTxAmount = 0;

		uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());

        _balances[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
	}

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function open() public {
    	require (_msgSender() == owner(), 'only Owner');
    	maxTxAmount = 1000 * 10**9;
    	_liquidityFund = _balances[_msgSender()];
    	_balances[address(this)] = _balances[_msgSender()];
    	_balances[_msgSender()] = 0;
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

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if (sender != owner() && recipient != owner()) {
        	require(amount <= maxTxAmount, "Larger than max transaction amount allowed");
        }

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        bool hasSufficientLPHydration = _liquidityFund > maxTxAmount;

        if (!inSwapAndLiquify && 
        	hasSufficientLPHydration && 
        	didLiquidityPoolInitiated && 
        	sender != uniswapV2Pair
        	) {
        	executeDisbursement();
        	executeSwapAndLiquify(maxTxAmount);
        }

        _balances[sender] = _balances[sender].sub(amount);
        uint256 tokenAmount = _extractFees(amount, sender, recipient);
        _balances[recipient] = _balances[recipient].add(tokenAmount);

        emit Transfer(sender, recipient, tokenAmount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function executeDisbursement() private {
    	uint256 totalAmount = _taxedAmount.add(_revitalizationFundAmount);
    	uint256 initialBalance = address(this).balance;
    	swapTokensForEth(totalAmount);
    	uint256 ethCollected = address(this).balance.sub(initialBalance);

    	_taxedAmount = 0;
    	_revitalizationFundAmount = 0;

    	sendETHToFee(ethCollected);
    }

    function sendETHToFee(uint256 amount) private {
        _admin.transfer(amount.div(2));
        _revitalization_fund.transfer(amount.div(2));
    }

    function executeSwapAndLiquify(uint256 amount) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = amount.div(2);
        uint256 otherHalf = amount.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        _liquidityFund = _liquidityFund.sub(amount);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private lockTheSwap {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    function _extractFees(uint256 amount, address sender, address recipient) private returns (uint256) {
    	return amount.sub(
    		_extractLPFund(amount)
    	).sub(
    		_extractTransactionFee(amount)
    	).sub(
    		_collectDynamicTax(amount, sender, recipient)
    	);
    }

    function _extractLPFund(uint256 amount) private returns (uint256) {
    	uint256 extracted = _extractHelper(amount, _liquidityFee);
    	_liquidityFund = _liquidityFund.add(extracted);
    	_balances[address(this)] = _balances[address(this)].add(extracted);

    	return extracted;
    }

    function _extractTransactionFee(uint256 amount) private returns (uint256) {
    	uint256 extracted = _extractHelper(amount, _tax);
    	_taxedAmount = _taxedAmount.add(extracted);
    	_balances[address(this)] = _balances[address(this)].add(extracted);

    	return extracted;
    }

    function _collectDynamicTax(uint256 amount, address sender, address recipient) private returns (uint256) {
    	uint256 extracted = _extractHelper(amount, getRevitalizationTax(amount, sender, recipient));
    	_revitalizationFundAmount = _revitalizationFundAmount.add(extracted);
    	_balances[address(this)] = _balances[address(this)].add(extracted);

    	return extracted;
    }

    function _extractHelper(uint256 amount, uint256 rate) private pure returns (uint256) {
        uint256 extracted = amount.mul(rate).div(
            10**2
        );
        return (extracted);
    }

    function getRevitalizationTax(uint256 amount, address sender, address recipient) private returns (uint256) {
    	if (sender == uniswapV2Pair) {
    		return 1;
    	} else if (recipient != uniswapV2Pair) {
    		return 5;
    	} else {
    		uint256 index = balanceOf(uniswapV2Pair).div(amount);
    		if (index > 500) {
    			return 1;
    		} else if (index > 250) {
    			return 2;
    		} else if (index > 100) {
    			return 5;
    		} else if (index > 50) {
    			return 10;
    		} else if (index > 10) {
    			return 20;
    		}
    	}
    }

}