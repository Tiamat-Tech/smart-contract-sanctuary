// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// (Uni|Pancake)Swap libs are interchangeable
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract ERC20Deflationary is ERC20Burnable, Ownable {
    // liquidity pool provider router
    IUniswapV2Router02 public _uniswapV2Router;

    address public _uniswapV2Pair;
    address private constant burnAccount =
        0x000000000000000000000000000000000000dEaD;
    address _router;

    address[] private _excludedFromReward;

    // Check whether currently swapping & liquifying
    bool private _inSwapAndLiquify;
    // Set to false if swapping and liquify should be performed manually
    bool private _isAutoSwapAndLiquify = true;

    event AutoSwapAndLiquifyUpdate(bool previous, bool current);
    event Burn(address from, uint256 amount);
    event BurnTaxUpdate(uint8 previous, uint8 current);
    event ExcludeFromFee(address account);
    event ExcludeFromReward(address account);
    event IncludeInFee(address account);
    event IncludeInReward(address account);
    event LiquidityTaxUpdate(uint8 previous, uint8 current);
    event MinTokensRequiredBeforeSwapUpdate(uint256 previous, uint256 current);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensAddedToLiquidity
    );
    event RewardTaxUpdate(uint8 previous, uint8 current);

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcludedFromReward;
    // balances for address that are included.
    mapping(address => uint256) private _rBalances;
    // balances for address that are excluded.
    mapping(address => uint256) private _tBalances;

    modifier lockTheSwap {
        require(!_inSwapAndLiquify, "Currently in swap and liquify");
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    // TODO: nested structs
    struct ValuesFromAmount {
        uint256 amount;
        uint256 tBurnFee;
        uint256 tRewardFee;
        uint256 tLiquidityFee;
        // amount after fee
        uint256 tTransferAmount;
        uint256 rAmount;
        uint256 rBurnFee;
        uint256 rRewardFee;
        uint256 rLiquidityFee;
        uint256 rTransferAmount;
    }

    uint8 private _decimals;
    // this percent of transaction amount that will be burnt.
    uint8 private _burnTax;
    // percent of transaction amount that will be added to the liquidity pool
    uint8 private _liquidityTax;
    // percent of transaction amount that will be redistribute to all holders.
    uint8 private _rewardTax;

    // For troubleshooting purposes
    uint256 private _currentSupply;
    // swap and liquify every 1 million tokens
    uint256 private _minTokensRequiredBeforeSwap = 10**6 * 10**_decimals;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 private _totalSupply;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        address router_,
        uint8 burnTax_,
        uint8 liquidityTax_,
        uint8 rewardTax_
    ) ERC20(name_, symbol_) {
        // Sets token vars
        _decimals = decimals_;
        _totalSupply = totalSupply_ * (10**decimals_);

        // Set helper vars
        _currentSupply = _totalSupply;
        _rTotal = (~uint256(0) - (~uint256(0) % _totalSupply));

        //  Set DEX platform up
        _uniswapV2Router = IUniswapV2Router02(router_);
        _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // Set the different taxes
        _burnTax = burnTax_;
        // _liquidityTax = liquidityTax_;
        _rewardTax = rewardTax_;

        // mint
        _rBalances[_msgSender()] = _rTotal;

        // exclude owner and this contract from fee.
        excludeFromFee(owner());
        excludeFromFee(address(this));

        // exclude owner, burnAccount, and this contract from receiving rewards.
        excludeFromReward(address(router_));
        excludeFromReward(address(this));
        excludeFromReward(burnAccount);

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (_isExcludedFromReward[account]) return _tBalances[account];
        return tokenFromReflection(_rBalances[account]);
    }

    /**
     * @dev See {IERC20-transfer}.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     */
    function _burn(address account, uint256 amount) internal override {
        require(account != burnAccount, "ERC20: burn from the burn address");

        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        uint256 rAmount = _getRValuesWithoutFee(amount);

        if (isExcluded(account)) {
            _tBalances[account] -= amount;
            _rBalances[account] -= rAmount;
        } else {
            _rBalances[account] -= rAmount;
        }

        _tBalances[burnAccount] += amount;
        _rBalances[burnAccount] += rAmount;

        // decrease the current coin supply
        _currentSupply -= amount;

        emit Burn(account, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        ValuesFromAmount memory values =
            _getValues(amount, _isExcludedFromFee[sender]);

        // Transfer from excluded
        if (
            _isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]
        ) {
            _tBalances[sender] = _tBalances[sender] - values.amount;
            _rBalances[sender] = _rBalances[sender] - values.rAmount;
            _rBalances[recipient] =
                _rBalances[recipient] +
                values.rTransferAmount;

            amount = values.tTransferAmount;
        }
        // Transfer to excluded
        else if (
            !_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]
        ) {
            _rBalances[sender] = _rBalances[sender] - values.rAmount;
            _tBalances[recipient] =
                _tBalances[recipient] +
                values.tTransferAmount;
            _rBalances[recipient] =
                _rBalances[recipient] +
                values.rTransferAmount;

            amount = values.tTransferAmount;
        }
        // Transfer both excluded
        else if (
            _isExcludedFromReward[sender] && _isExcludedFromReward[recipient]
        ) {
            _tBalances[sender] = _tBalances[sender] - values.amount;
            _rBalances[sender] = _rBalances[sender] - values.rAmount;
            _tBalances[recipient] =
                _tBalances[recipient] +
                values.tTransferAmount;
            _rBalances[recipient] =
                _rBalances[recipient] +
                values.rTransferAmount;

            amount = values.tTransferAmount;
        }
        // Transfer standard
        else {
            _rBalances[sender] = _rBalances[sender] - values.rAmount;
            _rBalances[recipient] =
                _rBalances[recipient] +
                values.rTransferAmount;
            amount = values.tTransferAmount;
        }

        emit Transfer(sender, recipient, amount);

        if (!_isExcludedFromFee[sender]) {
            _afterTokenTransfer(values);
        }
    }

    /**
     * Getters
     */
    function currentSupply() public view virtual returns (uint256) {
        return _currentSupply;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcludedFromReward[account];
    }

    function minTokensRequiredBeforeSwap()
        public
        view
        virtual
        returns (uint256)
    {
        return _minTokensRequiredBeforeSwap;
    }

    function liquidityTax() public view virtual returns (uint8) {
        return _liquidityTax;
    }

    function burnTax() public view virtual returns (uint8) {
        return _burnTax;
    }

    function rewardTax() public view virtual returns (uint8) {
        return _rewardTax;
    }

    function totalFees() public view virtual returns (uint256) {
        return _tFeeTotal;
    }

    /*
     * Setters
     */
    function setBurnTax(uint8 burnTax_) public onlyOwner {
        require(
            burnTax_ + _rewardTax + _liquidityTax < 100,
            "Total taxes {burn + liquidity + reward} exceeds 100%"
        );
        uint8 previous = _burnTax;
        _burnTax = burnTax_;
        emit BurnTaxUpdate(previous, _burnTax);
    }

    function setIsAutoSwapAndLiquify(bool state) public onlyOwner {
        bool previous = _isAutoSwapAndLiquify;
        _isAutoSwapAndLiquify = state;
        emit AutoSwapAndLiquifyUpdate(previous, state);
    }

    function setLiquidityTax(uint8 liquidityTax_) public onlyOwner {
        require(
            _burnTax + _rewardTax + liquidityTax_ < 100,
            "Total taxes {burn + liquidity + reward} exceeds 100%"
        );
        uint8 previous = _liquidityTax;
        _liquidityTax = liquidityTax_;
        emit LiquidityTaxUpdate(previous, _liquidityTax);
    }

    function setMinTokensRequiredBeforeSwap(
        uint256 minTokensRequiredBeforeSwap_
    ) public onlyOwner {
        uint256 contractBalance = _tBalances[address(this)];

        require(
            minTokensRequiredBeforeSwap_ < contractBalance,
            "Cannot exceed contract's balance"
        );
        uint256 previous = _minTokensRequiredBeforeSwap;
        _minTokensRequiredBeforeSwap = minTokensRequiredBeforeSwap_;

        emit MinTokensRequiredBeforeSwapUpdate(
            previous,
            _minTokensRequiredBeforeSwap
        );
    }

    function setRewardTax(uint8 rewardTax_) public onlyOwner {
        require(
            _burnTax + rewardTax_ + _liquidityTax < 100,
            "Total taxes {burn + liquidity + reward} exceeds 100%"
        );
        uint8 previous = _rewardTax;
        _rewardTax = rewardTax_;
        emit RewardTaxUpdate(previous, _rewardTax);
    }

    /**
     * Check for taxes and do relevant operations
     */
    function _afterTokenTransfer(ValuesFromAmount memory values)
        internal
        virtual
    {
        if (_burnTax != 0) {
            _tBalances[address(this)] += values.tBurnFee;
            _rBalances[address(this)] += values.rBurnFee;
            _approve(address(this), _msgSender(), values.tBurnFee);
            burnFrom(address(this), values.tBurnFee);
        }

        if (_liquidityTax != 0) {
            // add liquidity fee to this contract.
            _tBalances[address(this)] += values.tLiquidityFee;
            _rBalances[address(this)] += values.rLiquidityFee;

            uint256 contractBalance = _tBalances[address(this)];

            if (
                !_inSwapAndLiquify &&
                _isAutoSwapAndLiquify &&
                _msgSender() != _uniswapV2Pair
            ) {
                swapAndLiquify(contractBalance);
            }
        }

        if (_rewardTax != 0) {
            _distributeFee(values.rRewardFee, values.tRewardFee);
        }
    }

    // Required to receive payment
    receive() external payable {}

    /**
     * Liquidity related functions
     */
    function addLiquidity(uint256 ethAmount, uint256 tokenAmount) private {
        _approve(address(this), address(_uniswapV2Router), tokenAmount);

        // add the liquidity
        _uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function swapAndLiquify(uint256 contractBalance) private lockTheSwap {
        require(
            contractBalance >= _minTokensRequiredBeforeSwap,
            "Contract balance does not currently meet the minimum token threshold"
        );

        // split the contract balance into two halves.
        uint256 tokensToSwap = contractBalance / 2;
        uint256 tokensAddToLiquidity = contractBalance - tokensToSwap;

        // contract's current ETH balance.
        uint256 initialBalance = address(this).balance;

        // swap half of the tokens to ETH.
        swapTokensForEth(tokensToSwap);

        uint256 ethAddToLiquify = address(this).balance - initialBalance;

        addLiquidity(ethAddToLiquify, tokensAddToLiquidity);

        emit SwapAndLiquify(
            tokensToSwap,
            ethAddToLiquify,
            tokensAddToLiquidity
        );
    }

    function swapTokensForEth(uint256 amount) private lockTheSwap {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _uniswapV2Router.WETH();

        _approve(address(this), address(_uniswapV2Router), amount);

        // swap tokens to eth
        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /*
     * Reward related functions
     */

    // TODO: Check if needed - airdrop?
    function airdrop(uint256 amount) public {
        address sender = _msgSender();
        require(
            !_isExcludedFromReward[sender],
            "Excluded addresses cannot call this function"
        );
        ValuesFromAmount memory values = _getValues(amount, false);
        _rBalances[sender] = _rBalances[sender] - values.rAmount;
        _rTotal = _rTotal - values.rAmount;
        _tFeeTotal = _tFeeTotal + amount;
    }

    /**
     * @dev Distribute tokens to all holders that are included from reward.
     */
    function _distributeFee(uint256 rFee, uint256 tFee) private {
        // to decrease rate thus increase amount reward receive.
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    // TODO: figure out what this does...
    function reflectionFromToken(uint256 amount, bool deductTransferFee)
        public
        view
        returns (uint256)
    {
        require(amount <= _totalSupply, "Amount must be less than supply");
        ValuesFromAmount memory values = _getValues(amount, deductTransferFee);
        return values.rTransferAmount;
    }

    /**
        Used to figure out the balance of rBalance.
     */
    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /**
     * Values related functions
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _totalSupply;
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (
                _rBalances[_excludedFromReward[i]] > rSupply ||
                _tBalances[_excludedFromReward[i]] > tSupply
            ) return (_rTotal, _totalSupply);
            rSupply = rSupply - _rBalances[_excludedFromReward[i]];
            tSupply = tSupply - _tBalances[_excludedFromReward[i]];
        }
        if (rSupply < _rTotal / _totalSupply) return (_rTotal, _totalSupply);
        return (rSupply, tSupply);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getRValues(ValuesFromAmount memory values, bool deductTransferFee)
        private
        view
    {
        uint256 currentRate = _getRate();

        values.rAmount = values.amount * currentRate;

        if (deductTransferFee) {
            values.rTransferAmount = values.rAmount;
        } else {
            values.rAmount = values.amount * currentRate;
            values.rBurnFee = values.tBurnFee * currentRate;
            values.rRewardFee = values.tRewardFee * currentRate;
            values.rLiquidityFee = values.tLiquidityFee * currentRate;
            values.rTransferAmount =
                values.rAmount -
                values.rBurnFee -
                values.rRewardFee -
                values.rLiquidityFee;
        }
    }

    function _getRValuesWithoutFee(uint256 amount)
        private
        view
        returns (uint256)
    {
        uint256 currentRate = _getRate();
        return amount * currentRate;
    }

    function _getTValues(ValuesFromAmount memory values, bool deductTransferFee)
        private
        view
    {
        if (deductTransferFee) {
            values.tTransferAmount = values.amount;
        } else {
            // calculate fee
            values.tBurnFee = (values.amount * _burnTax) / (10**2);
            values.tRewardFee = (values.amount * _rewardTax) / (10**2);
            values.tLiquidityFee = (values.amount * _liquidityTax) / (10**2);

            // amount after fee
            values.tTransferAmount =
                values.amount -
                values.tBurnFee -
                values.tRewardFee -
                values.tLiquidityFee;
        }
    }

    function _getValues(uint256 amount, bool deductTransferFee)
        private
        view
        returns (ValuesFromAmount memory)
    {
        ValuesFromAmount memory values;
        values.amount = amount;
        _getTValues(values, deductTransferFee);
        _getRValues(values, deductTransferFee);
        return values;
    }

    // TODO: Simplify the following code (pretty merge)
    /*
     * Owner-only related functions
     */
    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcludedFromReward[account], "Account is already excluded");
        if (_rBalances[account] > 0) {
            _tBalances[account] = tokenFromReflection(_rBalances[account]);
        }
        _isExcludedFromReward[account] = true;
        _excludedFromReward.push(account);

        emit ExcludeFromReward(account);
    }

    function excludeFromFee(address account) public onlyOwner {
        require(!_isExcludedFromFee[account], "Account is already excluded");
        _isExcludedFromFee[account] = true;

        emit ExcludeFromFee(account);
    }

    function includeInReward(address account) public onlyOwner {
        require(_isExcludedFromReward[account], "Account is already included");
        for (uint256 i = 0; i < _excludedFromReward.length; i++) {
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[
                    _excludedFromReward.length - 1
                ];
                _tBalances[account] = 0;
                _isExcludedFromReward[account] = false;
                _excludedFromReward.pop();
                break;
            }
        }

        emit IncludeInReward(account);
    }

    function includeInFee(address account) public onlyOwner {
        require(_isExcludedFromFee[account], "Account already included");
        _isExcludedFromFee[account] = false;

        emit IncludeInFee(account);
    }
}