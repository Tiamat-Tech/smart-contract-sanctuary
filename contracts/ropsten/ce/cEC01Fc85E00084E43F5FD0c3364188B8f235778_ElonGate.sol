// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.9;

import "./../node_modules/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./../node_modules/@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./../node_modules/@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
    @title contract special for distribution tokens
*/
contract ElonGate is ERC20Upgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;

    uint256 private constant MAX = type(uint256).max;
    uint256 private constant _tTotal = 1000000000 * 10**6 * 10**9;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    uint256 public _maxTxAmount;
    uint256 public _taxFee;
    uint256 public _liquidityFee;
    bool public swapAndLiquifyEnabled;
    uint8 private _decimals;
    uint256 private numTokensSellToAddToLiquidity;

    uint256 private _previousTaxFee;
    uint256 private _previousLiquidityFee;

    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    address private _previousOwner;
    uint256 private _lockTime;

    address[] private _excluded;
    bool inSwapAndLiquify;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;

    event Threshold(uint256 threshold);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event Deliver(
        address indexed sender,
        uint256 rAmount,
        uint256 rTotal,
        uint256 tFeeTotal
    );
    event ExcludeFromReward(address indexed account, uint256 tOwned);
    event IncludeInReward(address indexed account, uint256 tOwned);
    event TransferFromSender(
        address indexed sender,
        uint256 tOwned,
        uint256 rOwned
    );
    event TransferToRecipient(
        address indexed recipient,
        uint256 tOwned,
        uint256 rOwned
    );
    event ExcludeFromFee(address indexed account, bool isExcludedFromFee);
    event IncludeInFee(address indexed account, bool isExcludedFromFee);
    event TaxFeePercent(uint256 taxFee);
    event LiquidityFeePercent(uint256 liquidityFee);
    event MaxTxPercent(uint256 maxTxAmount);
    event ReflectFee(uint256 rTotal, uint256 tFeeTotal);
    event TakeLiquidity(uint256 rOwned, uint256 tOwned);
    event RemoveAllFee(
        uint256 previousTaxFee,
        uint256 previousLiquidityFee,
        uint256 taxFee,
        uint256 liquidityFee
    );
    event RestoreAllFee(uint256 taxFee, uint256 liquidityFee);
    event TransferStandard(
        address indexed sender,
        address indexed recipient,
        uint256 rOwnedSender,
        uint256 rOwnedRecipient
    );
    event TransferToExcluded(
        address indexed sender,
        address indexed recipient,
        uint256 rOwnedSender,
        uint256 tOwnedRecipient,
        uint256 rOwnedRecipient
    );
    event TransferFromExcluded(
        address indexed sender,
        address indexed recipient,
        uint256 tOwnedSender,
        uint256 rOwnedSender,
        uint256 rOwnedRecipient
    );
    event WithdrawLeftovers(address indexed recipient, uint256 amount);
    event WithdrawAlienToken(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event ChangeRouter(address indexed router);
    event AddLiquidity(
        uint256 amountToken,
        uint256 amountETH,
        uint256 liquidity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier checkZeroAddress(address account) {
        require(account != address(0x0), "Address can not be zero's");
        _;
    }

    /**
        @notice receive ETH
        @dev to receive ETH from uniswapV2Router when swapping
    */
    receive() external payable {}

    /**
        @notice initialization
        @dev set address of router, create a uniswap pair and exclude from fee
        @param _router - address of router for initialize
    */
    function initialize(address _router, address _owner)
        external
        initializer
        checkZeroAddress(_router)
        checkZeroAddress(_owner)
    {
        _decimals = 9;
        _maxTxAmount = 5000000 * 10**6 * 10**9;
        numTokensSellToAddToLiquidity = 500000 * 10**6 * 10**9;
        _taxFee = 5;
        _liquidityFee = 5;
        swapAndLiquifyEnabled = true;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_owner] = _rTotal;
        __ERC20_init("ElonGate", "ElonGate");
        __Ownable_init();
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        _isExcludedFromFee[_owner] = true;
        _isExcludedFromFee[address(this)] = true;
        emit Transfer(address(0), _owner, _tTotal);
    }

    /**
        @notice determine the threshold for the accumulation
        @dev set the threshold by owner
        @param threshold - value of threshold
    */
    function setThreshold(uint256 threshold) external onlyOwner {
        numTokensSellToAddToLiquidity = threshold;
        emit Threshold(numTokensSellToAddToLiquidity);
    }

    /**
        @notice include account in reward
        @dev set address of account in reward and check exclude
        @param account - address for exclude and include in reward
    */
    function includeInReward(address account)
        external
        onlyOwner
        checkZeroAddress(account)
    {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                emit IncludeInReward(account, _tOwned[account]);
                break;
            }
        }
    }

    /**
        @notice set tax fee percent
        @dev set tax fee percent by owner
        @param taxFee - value of fee
    */
    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        require(taxFee <= 100, "taxFee can't exceeds 100%");
        _taxFee = taxFee;
        emit TaxFeePercent(_taxFee);
    }

    /**
        @notice set liquidity fee percent
        @dev set liquidity fee percent by owner
        @param liquidityFee - value of fee
    */
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        require(liquidityFee <= 100, "liquidityFee can't exceeds 100%");
        _liquidityFee = liquidityFee;
        emit LiquidityFeePercent(_liquidityFee);
    }

    /**
        @notice set max tx percent
        @dev set max tx percent with the previous calculation
        @param maxTxPercent - value for max tx percent
    */
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        require(maxTxPercent <= 100, "maxTxPercent can't exceeds 100%");
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
        emit MaxTxPercent(_maxTxAmount);
    }

    /**
        @notice set router
        @dev set address of router with the previous check address
        @param _router - address of router
    */
    function setRouter(address _router)
        external
        onlyOwner
        checkZeroAddress(_router)
    {
        uniswapV2Router = IUniswapV2Router02(_router);
        emit ChangeRouter(address(uniswapV2Router));
    }

    /**
        @notice withdraw the balance of the contract
        @dev withdraw amount of bnb that is as remainder in contract
    */
    function withdrawLeftovers() external onlyOwner {
        uint256 leftovers = address(this).balance;
        payable(owner()).transfer(leftovers);
        emit WithdrawLeftovers(owner(), leftovers);
    }

    /**
        @notice withdraw alien tokens from the balance of the contract
        @dev withdraw alien tokens that may have been mistakenly sent to the contract
        @param token - address of alien token
        @param recipient - address of account that get transfer's amount
        @param amount - amount for transfer
    */
    function withdrawAlienToken(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(token != address(this), "Token can not be elongate");
        require(amount != 0, "Amount can not be zero");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient tokens balance"
        );
        IERC20(token).transfer(recipient, amount);
        emit WithdrawAlienToken(token, recipient, amount);
    }

    /**
        @notice set value of a few variables depending on tAmount
        @dev set new value depending on tAmount and check account's exclude
        @param tAmount - value of amount for set new values for a few variables
    */
    function deliver(uint256 tAmount) external {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
        emit Deliver(sender, _rOwned[sender], _rTotal, _tFeeTotal);
    }

    /**
        @notice exclude account from reward
        @dev change value of _isExcluded, _tOwned (if need) and push account
        @param account - address of account
    */
    function excludeFromReward(address account)
        external
        onlyOwner
        checkZeroAddress(account)
    {
        require(!_isExcluded[account], "Account is not excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
        emit ExcludeFromReward(account, _tOwned[account]);
    }

    /**
        @notice exclude account from fee
        @dev change value of _isExcludedFromFee for this account
        @param account - address of account
    */
    function excludeFromFee(address account)
        external
        onlyOwner
        checkZeroAddress(account)
    {
        _isExcludedFromFee[account] = true;
        emit ExcludeFromFee(account, _isExcludedFromFee[account]);
    }

    /**
        @notice include account in fee
        @dev change value of _isExcludedFromFee for this account
        @param account - address of account
    */
    function includeInFee(address account)
        external
        onlyOwner
        checkZeroAddress(account)
    {
        _isExcludedFromFee[account] = false;
        emit IncludeInFee(account, _isExcludedFromFee[account]);
    }

    /**
        @notice return info about exclude account from fee
        @param account - address of account
        @return bool value of _isExcludedFromFee
    */
    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
        @notice set enable for swap and liquify
        @dev set value of swapAndLiquifyEnabled
        @param _enabled - bool value for add
    */
    function setSwapAndLiquifyEnabled(bool _enabled) external onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
        @notice return setted lock time
        @return value of variable _lockTime
    */
    function getUnlockTime() external view returns (uint256) {
        return _lockTime;
    }

    /**
        @notice locks the contract for owner
        @dev locks the contract for owner for the amount of time provided
        @param time - value for set time for lock
    */
    function lock(uint256 time) external onlyOwner {
        _previousOwner = owner();
        _transferOwnership(address(0));
        _lockTime = block.timestamp + time;
    }

    /**
        @notice unlock the contract for owner
        @dev unlocks the contract for owner when _lockTime is exceeds
    */
    function unlock() external {
        require(
            _previousOwner == _msgSender(),
            "You don't have permission to unlock"
        );
        require(block.timestamp > _lockTime, "Contract is locked until 7 days");
        _transferOwnership(_previousOwner);
    }

    /**
        @notice return info about exclude account from reward
        @dev return value of variable for save info about exclude account
        @param account - address of account
        @return bool value about exclude account
    */
    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcluded[account];
    }

    /**
        @notice return value of total fees
        @return value of variable _tFeeTotal
    */
    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    /**
        @notice return reflection from token
        @dev return reflection from token depending on value of deductTransferFee
        @param tAmount - value of amount for get values of a few variables
        @param deductTransferFee - bool value for get special result
        @return value of rAmount or rTransferAmount depending on deductTransferFee
    */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        external
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
        @notice return balance of account
        @dev return account's balance depending on account's exclude
        @param account - address of account
        @return balance of account
    */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
        @notice return value of total supply
        @return value of variable _tTotal
    */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /**
        @notice return value of decimals
        @return value of variable _decimals
    */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
        @notice return token from reflection
        @dev return token from reflection as result of calculation
        @param rAmount - value of amount for calculation
        @return result of calculation
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
        return rAmount.div(currentRate);
    }

    /**
        @notice transfer amount, add liquidity
        @dev check amount and accounts, transfer will take fee, add liquidity
        @param from - address of account that transfer amount
        @param to - address of account that get transfer's amount
        @param amount - value of amount for transfer
    */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if (from != owner() && to != owner())
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
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
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }
        _tokenTransfer(from, to, amount, takeFee);
    }

    /**
        @notice transfer amount if both accounts excluded from reward
        @dev change values of a few variables, reflect fee and take liquidity
        @param sender - address of account that transfer amount
        @param recipient - address of account that get transfer's amount
        @param tAmount - value of amount for transfer
    */
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferFromSender(sender, _tOwned[sender], _rOwned[sender]);
        emit TransferToRecipient(
            recipient,
            _tOwned[recipient],
            _rOwned[recipient]
        );
    }

    /**
        @notice reflect fee
        @dev change values of _rTotal and _tFeeTotal
        @param rFee - value for subtract from _rTotal
        @param tFee - value for add to _tFeeTotal
    */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
        emit ReflectFee(_rTotal, _tFeeTotal);
    }

    /**
        @notice return tValues and rValues
        @dev return values depending on tAmount
        @param tAmount - value for calculate return values
        @return rAmount - value as result of calculating tAmount and rate
        @return rTransferAmount - value as result of calculating rAmount, rFee and rLiquidity
        @return rFee - value as result of calculating tFee and rate
        @return tTransferAmount - value as result of calculating tAmount, tFee and tLiquidity
        @return tFee - value as result of calculating _taxFee and tAmount
        @return tLiquidity - value as result of calculating _liquidityFee and tAmount
    */
    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    /**
        @notice return tValues
        @dev return values depending on tAmount
        @param tAmount - value for calculate return values
        @return tTransferAmount - value as result of calculating tAmount, tFee and tLiquidity
        @return tFee - value as result of calculating _taxFee and tAmount
        @return tLiquidity - value as result of calculating _liquidityFee and tAmount
    */
    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    /**
        @notice return rValues
        @dev return values depending on values of parameters
        @param tAmount - value for calculate rAmount
        @param tFee - value for calculate rFee
        @param tLiquidity - value for calculate rLiquidity
        @param currentRate - value for calculate return's values
        @return rAmount - value as result of calculating tAmount and currentRate
        @return rTransferAmount - value as result of calculating rAmount, rFee and rLiquidity
        @return rFee - value as result of calculating tFee and currentRate
    */
    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
        @notice return rate
        @dev return values depending on r and t values
        @return value as result of calculating rSupply and tSupply
    */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    /**
        @notice return current supply
        @dev return values depending on r and t values
        @return r and t values depending on condition
    */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
        @notice should take liquidity
        @dev change values of _rOwned and _tOwned depending on tLiquidity
        @param tLiquidity - value for correct change values of variables
    */
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
        emit TakeLiquidity(_rOwned[address(this)], _tOwned[address(this)]);
    }

    /**
        @notice return tax fee
        @dev return tax fee as result of calculating
        @param _amount - value for correct calculating
        @return result of calculating
    */
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    /**
        @notice return liquidity fee
        @dev return liquidity fee as result of calculating
        @param _amount - value for correct calculating
        @return result of calculating
    */
    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    /**
        @notice remove all fee
        @dev change values of variables relationed fee
    */
    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _taxFee = 0;
        _liquidityFee = 0;
        emit RemoveAllFee(
            _previousTaxFee,
            _previousLiquidityFee,
            _taxFee,
            _liquidityFee
        );
    }

    /**
        @notice restore all fee
        @dev change values of variables relationed fee
    */
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        emit RestoreAllFee(_taxFee, _liquidityFee);
    }

    /**
        @notice should swap tokens and liquify
        @dev split the balance, exchange tokens for ETH and add liquidity
        @param contractTokenBalance - contract's balance
    */
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half);
        uint256 newBalance = address(this).balance.sub(initialBalance);
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /**
        @notice should swap tokens for ETH
        @dev add approve, generate uniswap pair and swap
        @param tokenAmount - amount of tokens for swap
    */
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

    /**
        @notice should add liquidity
        @dev add approve and liquidity ETH
        @param tokenAmount - amount of tokens for approve and liquidity
        @param ethAmount - amount of ETH for call functions for add liquidity
    */
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        ) = uniswapV2Router.addLiquidityETH{value: ethAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                owner(),
                block.timestamp
            );
        emit AddLiquidity(amountToken, amountETH, liquidity);
    }

    /**
        @notice should transfer tokens
        @dev this method is responsible for taking all fee, if takeFee is true
        @param sender - address of account that transfer amount
        @param recipient - address of account that get transfer's amount
        @param amount - value of amount for transfer
        @param takeFee - value that indicates the possibility of deducting fee
    */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        if (!takeFee) restoreAllFee();
    }

    /**
        @notice standard transfer amount
        @dev change values of a few variables, reflect fee and take liquidity
        @param sender - address of account that transfer amount
        @param recipient - address of account that get transfer's amount
        @param tAmount - value of amount for transfer
    */
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferStandard(
            sender,
            recipient,
            _rOwned[sender],
            _rOwned[recipient]
        );
    }

    /**
        @notice transfer amount if recipient include in reward
        @dev change values of a few variables, reflect fee and take liquidity
        @param sender - address of account that transfer amount
        @param recipient - address of account that get transfer's amount
        @param tAmount - value of amount for transfer
    */
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferToExcluded(
            sender,
            recipient,
            _rOwned[sender],
            _tOwned[recipient],
            _rOwned[recipient]
        );
    }

    /**
        @notice transfer amount if sender include in reward
        @dev change values of a few variables, reflect fee and take liquidity
        @param sender - address of account that transfer amount
        @param recipient - address of account that get transfer's amount
        @param tAmount - value of amount for transfer
    */
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit TransferFromExcluded(
            sender,
            recipient,
            _tOwned[sender],
            _rOwned[sender],
            _rOwned[recipient]
        );
    }
}