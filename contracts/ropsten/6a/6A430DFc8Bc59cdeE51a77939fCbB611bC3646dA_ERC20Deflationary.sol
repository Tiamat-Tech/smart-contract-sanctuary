// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// (Uni|Pancake)Swap libs are interchangeable
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// TODO: Set view/pure
contract ERC20Deflationary is ERC20Burnable, Ownable {
    IUniswapV2Router02 private _uniswapV2Router; // Liquidity pool provider router

    address private _uniswapV2Pair; // This Token and WETH pair contract address.
    address private _router;

    address[] private _excludedFromGettingRewards; // An array of addresses that are excluded from reward.

    bool private _inSwapAndLiquify; // Check whether currently swapping & liquifying
    bool private _isAutoSwapAndLiquify = true; // Set to "false" if swapping and liquify should be performed manually

    event Airdrop(uint256 amount);
    event AutoSwapAndLiquifyUpdate(bool previous, bool current);
    event Burn(address from, uint256 amount);
    event BurnTaxUpdate(uint8 previous, uint8 current);
    event DistributeRewards(uint256 rFee, uint256 tFee);
    event ExcludeFromPayingFeesUpdate(address account, bool state);
    event ExcludeFromGettingRewardsUpdate(address account, bool state);
    event LiquidityTaxUpdate(uint8 previous, uint8 current);
    event MinTokensRequiredBeforeSwapUpdate(uint256 previous, uint256 current);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 liquidity,
        uint256 liquidityETH
    );
    event RewardTaxUpdate(uint8 previous, uint8 current);

    mapping(address => bool) private _isExcludedFromPayingFees; // Keeps track of which address are excluded from fee.
    mapping(address => bool) private _isExcludedFromGettingRewards; // Keeps track of which address are excluded from reward.
    mapping(address => uint256) private _reflectionBalances; // Keeps track of balances for addresses that are included in receiving reward.
    mapping(address => uint256) private _tokenBalances; // Keeps track of balances for addresses that are excluded from receiving reward.

    modifier lessThan100(
        uint256 burnTax,
        uint256 liquidityTax,
        uint256 rewardTax
    ) {
        require(
            burnTax + liquidityTax + rewardTax < 100,
            "lessThan100: sum of taxes must not exceed 100%"
        );
        _;
    }
    modifier notNull(uint256 amount) {
        require(amount > 0, "notNull: 'amount' cannot be null");
        _;
    }
    modifier notPrevious(uint256 current, uint256 previous) {
        require(
            current != previous,
            "notPrevious: 'current' must differ from 'previous'"
        );
        _;
    }
    modifier swapLocked {
        require(
            !_inSwapAndLiquify,
            "swapLocked: currently swapping and liquifying..."
        );
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    struct ReflectionValues {
        uint256 amount; // Reflection of amount.
        uint256 burnFee; // Reflection of burn fee.
        uint256 rewardFee; // Reflection of reward fee.
        uint256 liquidityFee; // Reflection of liquify fee.
        uint256 transferAmount; // Reflection of transfer amount.
    }
    struct TokenValues {
        uint256 amount; // Amount of tokens for to transfer.
        uint256 burnFee; // Amount tokens charged for burning.
        uint256 rewardFee; // Amount tokens charged to reward.
        uint256 liquidityFee; // Amount tokens charged to add to liquidity.
        uint256 transferAmount; // Amount tokens after fees.
    }

    uint8 private _decimals;
    uint8 private _burnTax; // this percent of transaction amount that will be burnt.
    uint8 private _liquidityTax; // percent of transaction amount that will be added to the liquidity pool
    uint8 private _rewardTax; // percent of transaction amount that will be redistribute to all holders.

    uint256 private _currentSupply; // Current supply:= total supply - burnt tokens (for debugging)
    uint256 private _minTokensRequiredBeforeSwap; // swap and liquify every 1 million tokens
    uint256 private _reflectionTotal; // A number that helps distributing fees to all holders respectively.
    uint256 private _totalLiquidityETH; // Total amount of ETH locked in the LP (this token and WETH pair).
    uint256 private _totalSupply;
    uint256 private _totalTokensBurnt; // Total amount of tokens rewarded / distributing.
    uint256 private _totalTokensRewarded; // Total amount of tokens rewarded / distributing.
    uint256 private _totalLiquidity; // Total amount of tokens locked in the LP (this token and WETH pair).

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
        _reflectionTotal = (~uint256(0) - (~uint256(0) % _totalSupply));
        _minTokensRequiredBeforeSwap = 10**6 * 10**_decimals;

        //  Set DEX platform up
        _uniswapV2Router = IUniswapV2Router02(address(router_));

        address pair =
            IUniswapV2Factory(_uniswapV2Router.factory()).getPair(
                _uniswapV2Router.WETH(),
                address(this)
            );

        // Pair not yet created
        if (pair == address(0)) {
            _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
                .createPair(_uniswapV2Router.WETH(), address(this));
        } else {
            _uniswapV2Pair = pair;
        }

        // Set the different taxes
        _burnTax = burnTax_;
        _liquidityTax = liquidityTax_;
        _rewardTax = rewardTax_;

        _reflectionBalances[_msgSender()] = _reflectionTotal; // mint

        setIsExcludedFromPayingFees(address(_uniswapV2Router), true); // exclude uniswapV2Router from paying fees.
        setIsExcludedFromPayingFees(_uniswapV2Pair, true); // exclude WETH and this Token Pair from paying fees.
        setIsExcludedFromPayingFees(owner(), true);
        setIsExcludedFromPayingFees(address(this), true);

        setIsExcludedFromGettingRewards(address(_uniswapV2Router), true); // exclude uniswapV2Router from receiving reward.
        setIsExcludedFromGettingRewards(_uniswapV2Pair, true); // exclude WETH and this Token Pair from receiving reward.
        setIsExcludedFromGettingRewards(address(this), true); // exclude this contract from receiving reward.

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
        if (_isExcludedFromGettingRewards[account])
            return _tokenBalances[account];

        return tokenFromReflection(_reflectionBalances[account]);
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
    function _burn(address account, uint256 amount)
        internal
        override
        notNull(amount)
    {
        require(account != address(0), "ERC20: burn from the zero address");
        require(
            balanceOf(account) >= amount,
            "ERC20: burn amount exceeds balance"
        );

        uint256 rAmount = _getRValuesWithoutFee(amount);

        // Transfer from account to the burnAddress
        if (_isExcludedFromGettingRewards[account]) {
            _tokenBalances[account] -= amount;
        }

        _reflectionBalances[account] -= rAmount;
        _tokenBalances[address(0)] += amount;
        _reflectionBalances[address(0)] += rAmount;
        _currentSupply -= amount;
        _totalTokensBurnt += amount;

        emit Burn(account, amount);
    }

    /**
     * @dev See {IERC20-transferFrom}.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override notNull(amount) {
        require(
            balanceOf(sender) >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(
            sender != recipient,
            "_transfer: 'sender' cannot also be 'recipient'"
        );

        TokenValues memory tokenValues =
            _getTValues(amount, _isExcludedFromPayingFees[sender]);
        ReflectionValues memory reflectionValues =
            _getRValues(tokenValues, _isExcludedFromPayingFees[sender]);

        // Transfer from excluded
        if (
            _isExcludedFromGettingRewards[sender] &&
            !_isExcludedFromGettingRewards[recipient]
        ) {
            _tokenBalances[sender] =
                _tokenBalances[sender] -
                tokenValues.amount;
            _reflectionBalances[sender] =
                _reflectionBalances[sender] -
                reflectionValues.amount;
            _reflectionBalances[recipient] =
                _reflectionBalances[recipient] +
                reflectionValues.transferAmount;
        }
        // Transfer to excluded
        else if (
            !_isExcludedFromGettingRewards[sender] &&
            _isExcludedFromGettingRewards[recipient]
        ) {
            _reflectionBalances[sender] =
                _reflectionBalances[sender] -
                reflectionValues.amount;
            _tokenBalances[recipient] =
                _tokenBalances[recipient] +
                tokenValues.transferAmount;
            _reflectionBalances[recipient] =
                _reflectionBalances[recipient] +
                reflectionValues.transferAmount;
        }
        // Transfer both excluded
        else if (
            _isExcludedFromGettingRewards[sender] &&
            _isExcludedFromGettingRewards[recipient]
        ) {
            _tokenBalances[sender] =
                _tokenBalances[sender] -
                tokenValues.amount;
            _reflectionBalances[sender] =
                _reflectionBalances[sender] -
                reflectionValues.amount;
            _tokenBalances[recipient] =
                _tokenBalances[recipient] +
                tokenValues.transferAmount;
            _reflectionBalances[recipient] =
                _reflectionBalances[recipient] +
                reflectionValues.transferAmount;
        }
        // Transfer standard
        else {
            _reflectionBalances[sender] =
                _reflectionBalances[sender] -
                reflectionValues.amount;
            _reflectionBalances[recipient] =
                _reflectionBalances[recipient] +
                reflectionValues.transferAmount;
        }

        emit Transfer(sender, recipient, tokenValues.transferAmount);

        if (!_isExcludedFromPayingFees[sender]) {
            _afterTokenTransfer(reflectionValues, tokenValues);
        }
    }

    /**
     * Getters
     */
    function getBurnTax() public view virtual returns (uint8) {
        return _burnTax;
    }

    function getCurrentSupply() public view virtual returns (uint256) {
        return _currentSupply;
    }

    function getIsAutoSwapAndLiquify() public view returns (bool) {
        return _isAutoSwapAndLiquify;
    }

    function getIsExcludedFromPayingFees(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromPayingFees[account];
    }

    function getIsExcludedFromGettingRewards(address account)
        public
        view
        returns (bool)
    {
        return _isExcludedFromGettingRewards[account];
    }

    function getLiquidityTax() public view virtual returns (uint8) {
        return _liquidityTax;
    }

    function getMinTokensRequiredBeforeSwap()
        public
        view
        virtual
        returns (uint256)
    {
        return _minTokensRequiredBeforeSwap;
    }

    function getRewardTax() public view virtual returns (uint8) {
        return _rewardTax;
    }

    /**
     * @dev Returns the total number of tokens burnt.
     */
    function getTotalTokensBurnt() external view virtual returns (uint256) {
        return _totalTokensBurnt;
    }

    /**
     * @dev Returns the total number of tokens locked in the LP.
     */
    function getTotalLiquidity() external view virtual returns (uint256) {
        return _totalLiquidity;
    }

    /**
     * @dev Returns the total number of ETH locked in the LP.
     */
    function getTotalLiquidityETH() external view virtual returns (uint256) {
        return _totalLiquidityETH;
    }

    function getTotalTokensRewarded() public view virtual returns (uint256) {
        return _totalTokensRewarded;
    }

    /*
     * Setters
     */
    function setBurnTax(uint8 burnTax_)
        public
        lessThan100(burnTax_, _liquidityTax, _rewardTax)
        notPrevious(burnTax_, _burnTax)
        onlyOwner
    {
        uint8 previous = _burnTax;

        _burnTax = burnTax_;

        emit BurnTaxUpdate(previous, _burnTax);
    }

    function setIsAutoSwapAndLiquify(bool state) public onlyOwner {
        require(
            state != _isAutoSwapAndLiquify,
            "setIsAutoSwapAndLiquify: 'state' already (true|false)"
        );

        bool previous = _isAutoSwapAndLiquify;

        _isAutoSwapAndLiquify = state;

        emit AutoSwapAndLiquifyUpdate(previous, state);
    }

    function setIsExcludedFromGettingRewards(address account, bool state)
        public
        onlyOwner
    {
        require(
            state != _isExcludedFromGettingRewards[account],
            "setIsExcludedFromGettingRewards: 'account' already (included|excluded)"
        );

        if (state) {
            if (_reflectionBalances[account] > 0) {
                _tokenBalances[account] = tokenFromReflection(
                    _reflectionBalances[account]
                );
            }
            _isExcludedFromGettingRewards[account] = true;
            _excludedFromGettingRewards.push(account);
        } else {
            for (uint256 i = 0; i < _excludedFromGettingRewards.length; i++) {
                if (_excludedFromGettingRewards[i] == account) {
                    _excludedFromGettingRewards[
                        i
                    ] = _excludedFromGettingRewards[
                        _excludedFromGettingRewards.length - 1
                    ];
                    _tokenBalances[account] = 0;
                    _isExcludedFromGettingRewards[account] = false;
                    _excludedFromGettingRewards.pop();
                    break;
                }
            }
        }

        emit ExcludeFromGettingRewardsUpdate(account, state);
    }

    function setIsExcludedFromPayingFees(address account, bool state)
        public
        onlyOwner
    {
        require(
            state != _isExcludedFromPayingFees[account],
            "setIsExcludedFromPayingFees: 'account' already (included|excluded)"
        );

        if (state) {
            _isExcludedFromPayingFees[account] = true;
        } else {
            _isExcludedFromPayingFees[account] = false;
        }

        emit ExcludeFromPayingFeesUpdate(account, state);
    }

    function setLiquidityTax(uint8 liquidityTax_)
        public
        lessThan100(_burnTax, liquidityTax_, _rewardTax)
        notPrevious(liquidityTax_, _liquidityTax)
        onlyOwner
    {
        uint8 previous = _liquidityTax;

        _liquidityTax = liquidityTax_;

        emit LiquidityTaxUpdate(previous, _liquidityTax);
    }

    function setMinTokensRequiredBeforeSwap(
        uint256 minTokensRequiredBeforeSwap_
    )
        public
        notNull(minTokensRequiredBeforeSwap_)
        notPrevious(minTokensRequiredBeforeSwap_, _minTokensRequiredBeforeSwap)
        onlyOwner
    {
        // require(
        //     minTokensRequiredBeforeSwap_ < _tokenBalances[address(this)],
        //     "setMinTokensRequiredBeforeSwap: 'minTokensRequiredBeforeSwap_' must be lower than '_tokenBalances[address(this)]'"
        // );

        uint256 previous = _minTokensRequiredBeforeSwap;

        _minTokensRequiredBeforeSwap = minTokensRequiredBeforeSwap_;

        emit MinTokensRequiredBeforeSwapUpdate(
            previous,
            _minTokensRequiredBeforeSwap
        );
    }

    function setRewardTax(uint8 rewardTax_)
        public
        lessThan100(_burnTax, _liquidityTax, rewardTax_)
        notPrevious(rewardTax_, _rewardTax)
        onlyOwner
    {
        uint8 previous = _rewardTax;

        _rewardTax = rewardTax_;

        emit RewardTaxUpdate(previous, _rewardTax);
    }

    /**
     * Check for taxes and do relevant operations
     */
    function _afterTokenTransfer(
        ReflectionValues memory reflectionValues,
        TokenValues memory tokenValues
    ) private {
        if (_burnTax != 0) {
            _tokenBalances[address(this)] += tokenValues.burnFee;
            _reflectionBalances[address(this)] += reflectionValues.burnFee;
            // - the caller must have allowance for ``accounts``'s tokens of at least
            //  `amount`.
            _approve(address(this), _msgSender(), tokenValues.burnFee);
            burnFrom(address(this), tokenValues.burnFee);
        }

        if (_liquidityTax != 0) {
            // add liquidity fee to this contract.
            _tokenBalances[address(this)] += tokenValues.liquidityFee;
            _reflectionBalances[address(this)] += reflectionValues.liquidityFee;
            uint256 contractBalance = _tokenBalances[address(this)];
            // Whether the current contract balances makes the threshold to swap and liquify.
            bool overMinTokensBeforeSwap =
                contractBalance >= _minTokensRequiredBeforeSwap;
            if (
                overMinTokensBeforeSwap &&
                !_inSwapAndLiquify &&
                _isAutoSwapAndLiquify &&
                _msgSender() != _uniswapV2Pair
            ) {
                swapAndLiquify(contractBalance);
            }
        }

        if (_rewardTax != 0) {
            _distributeRewards(
                reflectionValues.rewardFee,
                tokenValues.rewardFee
            );
        }
    }

    // Required to receive payment
    receive() external payable {}

    /**
     * Liquidity related functions
     */

    /**
     * @dev Swap half of contract's token balance for ETH,
     * and pair it up with the other half to add to the
     * liquidity pool.
     *
     * Emits {SwapAndLiquify} event indicating the amount of tokens swapped to eth,
     * the amount of ETH added to the LP, and the amount of tokens added to the LP.
     */
    function swapAndLiquify(uint256 contractBalance) private swapLocked {
        // split the contract balance into two halves.
        uint256 tokensToSwap = contractBalance / 2;
        uint256 tokensToAddToLiq = contractBalance - tokensToSwap;

        // contract's current BNB/ETH balance.
        uint256 initialBalance = address(this).balance;

        _approve(address(this), address(_uniswapV2Router), tokensToSwap);

        // swap half of the tokens to ETH.
        address[] memory path = new address[](2);
        path[0] = _uniswapV2Router.WETH();
        path[1] = address(this);

        // Swap tokens for ETH/BNB
        _uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSwap,
            0,
            path,
            address(this), // this contract will receive the eth that were swapped from the token
            block.timestamp + 60 * 1000
        );

        // Figure out the exact amount of tokens received from swapping.
        // Check: https://github.com/Uniswap/uniswap-v2-periphery/issues/92
        uint256 ethReceived = address(this).balance - initialBalance;

        // To cover all possible scenarios, msg.sender should have already given
        // the router an allowance of at least amountTokenDesired on token.
        _approve(address(this), address(_uniswapV2Router), ethReceived);

        (uint256 amountToken, uint256 amountETH, ) =
            _uniswapV2Router.addLiquidityETH{value: ethReceived}(
                address(this),
                tokensToAddToLiq,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                owner(),
                block.timestamp + 60 * 1000
            );

        _totalLiquidityETH += amountETH;
        _totalLiquidity += amountToken;

        emit SwapAndLiquify(tokensToSwap, amountToken, amountETH);
    }

    /*
     * Reward related functions
     */
    function airdrop(address[] memory recipients, uint256[] memory values)
        public
    {
        for (uint256 i = 0; i < recipients.length; i++) {
            transfer(recipients[i], values[i]);
        }
    }

    /**
     * @dev Distribute the `tRewardFee` tokens to all holders that are included in receiving reward.
     * amount received is based on how many token one owns.
     */
    function _distributeRewards(uint256 reflectionFee, uint256 tokenFee)
        private
    {
        // to decrease rate thus increase amount reward receive.
        _reflectionTotal = _reflectionTotal - reflectionFee;
        _totalTokensRewarded = _totalTokensRewarded + tokenFee;

        emit DistributeRewards(_reflectionTotal, _totalTokensRewarded);
    }

    /**
     * @dev Used to figure out the balance after reflection.
     * Requirements:
     * - `amount` must be less than reflectTotal.
     */
    function tokenFromReflection(uint256 amount)
        private
        view
        returns (uint256)
    {
        require(
            amount <= _reflectionTotal,
            "tokenFromReflection: 'amount' must be lower than '_reflectionTotal'"
        );

        uint256 currentRate = _getRate();

        return amount / currentRate;
    }

    /**
     * Helpers
     */
    /**
     * @dev Returns the current reflection supply and token supply.
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _reflectionTotal;
        uint256 tSupply = _totalSupply;

        for (uint256 i = 0; i < _excludedFromGettingRewards.length; i++) {
            if (
                _reflectionBalances[_excludedFromGettingRewards[i]] > rSupply ||
                _tokenBalances[_excludedFromGettingRewards[i]] > tSupply
            ) return (_reflectionTotal, _totalSupply);

            rSupply =
                rSupply -
                _reflectionBalances[_excludedFromGettingRewards[i]];
            tSupply = tSupply - _tokenBalances[_excludedFromGettingRewards[i]];
        }

        if (rSupply < _reflectionTotal / _totalSupply)
            return (_reflectionTotal, _totalSupply);

        return (rSupply, tSupply);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();

        return rSupply / tSupply;
    }

    function _getRValues(TokenValues memory tokenValues, bool deductTransferFee)
        private
        view
        returns (ReflectionValues memory)
    {
        ReflectionValues memory reflectionValues;
        uint256 currentRate = _getRate();

        reflectionValues.amount = tokenValues.amount * currentRate;

        if (deductTransferFee) {
            reflectionValues.transferAmount = tokenValues.amount * currentRate;
        } else {
            reflectionValues.burnFee = tokenValues.burnFee * currentRate;
            reflectionValues.rewardFee = tokenValues.rewardFee * currentRate;
            reflectionValues.liquidityFee =
                tokenValues.liquidityFee *
                currentRate;
            reflectionValues.transferAmount =
                reflectionValues.amount -
                reflectionValues.burnFee -
                reflectionValues.rewardFee -
                reflectionValues.liquidityFee;
        }

        return reflectionValues;
    }

    function _getRValuesWithoutFee(uint256 amount)
        private
        view
        returns (uint256)
    {
        return amount * _getRate();
    }

    function _getTValues(uint256 amount, bool deductTransferFee)
        private
        view
        returns (TokenValues memory)
    {
        TokenValues memory tokenValues;

        tokenValues.amount = amount;

        if (deductTransferFee) {
            tokenValues.transferAmount = amount;
        } else {
            // calculate fee
            tokenValues.burnFee = (amount * _burnTax) / (10**2);
            tokenValues.rewardFee = (amount * _rewardTax) / (10**2);
            tokenValues.liquidityFee = (amount * _liquidityTax) / (10**2);
            // amount after fee
            tokenValues.transferAmount =
                amount -
                tokenValues.burnFee -
                tokenValues.rewardFee -
                tokenValues.liquidityFee;
        }

        return tokenValues;
    }
}