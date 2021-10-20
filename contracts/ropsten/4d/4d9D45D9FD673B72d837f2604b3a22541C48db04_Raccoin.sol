/**
   Raccoin

   Token features:
   4% fee auto distribute to all holders
   2% fee to the team wallet - this gives transparency and avoids the team dumping without you knowing about it!
   4% fee auto add to the liquidity pool to locked forever

   - Liquidity pool tokens locked at launch (It's rug-proof)

 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Access Control
import "@openzeppelin/contracts/access/Ownable.sol";

// Utils
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Interfaces
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// This is the ERC20 implementation which we can override freely
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// These will allow us to interact with the basic functionality of
// PancakeSwap...
// The contracts to mention UniswapV2 but that's because PCS is based
// on Uniswap, so these are the official interfaces
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

//import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol"

contract Raccoin is ERC20("Raccoin", "RACN"), Ownable {
    using SafeMath for uint256;
    using Address for address;

    // *** PARAMS
    uint8 private constant _decimals = 8;
    uint256 private constant MAX = ~uint256(0);

    //TODO: identify, 1k tokens
    uint256 private numTokensSellToAddToLiquidity = 100 * 10**3 * 10**_decimals;

    // *** FEES
    uint256 public _taxFee = 4;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _liquidityFee = 4;
    uint256 private _previousLiquidityFee = _liquidityFee;

    /*
    uint256 public _extraLiquidityFeeOnSell = 2;
    uint256 private _previousExtraLiquidityFeeOnSell = _extraLiquidityFeeOnSell;

    uint256 public _dumpPenaltyLiquidityFee = 5;
    uint256 private _previousDumpPenaltyLiquidityFee = _dumpPenaltyLiquidityFee;

    //Time for dump penalty counter to be reset
    uint256 public dumpPenaltyTimer = 1 days;
    //75k
    uint256 public numTokensDumpPenalty = 75 * 10**3 * 10**_decimals;

    //150k, tells the maximum amount allowed to sell in total
    //until `dumpPenaltyTimer` is reset
    uint256 public numTokensMaxPerDumpPenaltyReset =
        150 * 10**3 * 10**_decimals;
     */

    uint256 public _devFee = 2;
    uint256 private _previousDevFee = _devFee;
    address public devWallet = 0xA63d6E5833BbC6f420195174Ab2f2F2431d8CC56;

    //Total token supply (1.5 bil)
    uint256 private _tTotal = 15 * 10**8 * 10**_decimals;

    // *** PER-ADDRESS SETTINGS
    mapping(address => bool) private _isExcludedFromFee;

    /*
    struct AntiDumpData {
        // time when count is supposed to reset (after `dumpPenaltyTimer`)
        uint256 time;
        // count of total tokens sold
        uint256 count;
    }
    mapping(address => AntiDumpData) private _antiDump;
     */

    //excluded from rewards (taxFee?)
    mapping(address => bool) private _isExcluded;
    //TODO: double mapping?
    address[] private _excluded;

    // *** BALANCES
    //TODO: identify, rewards owned by a certain address?
    mapping(address => uint256) private _rOwned;
    //TODO: identify, tokens owned by a certain address?
    mapping(address => uint256) private _tOwned;

    //TODO identify... reflection total ? used in algorithms below
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    // *** AMM
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    // *** MISC
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    // *** EVENTS
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

    constructor() {
        //TODO: enable in prod
        transferOwnership(0x65e722237f968C84cD04809A12599178a0F0Bc9a);

        //who deployed the contract gets all the tokens
        _rOwned[owner()] = _rTotal;

        // PCSv2 Router
        // 0x10ED43C718714eb63d5aA57B78B54704E256024E

        // PCSv2 Testnet
        // 0xD99D1c33F9fC3444f8101754aBC46c52416550D1

        // Kietmie's
        // 0x10ED43C718714eb63d5aA57B78B54704E256024E

        // UNISWAPV2Router02 GOERLI
        // 0x05Edc8Ed2A12D22cF979d7Bd9BAD48397c69a18d

        // UNISWAPV2Router 02 ROPSTEN
        // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        IUniswapV2Router02 _uniswapV2Router =
            IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        // Create a uniswap pair for this new token
        //in this case RACN-WETH (which is WBNB in PCS)
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[devWallet] = true; //also exclude dev wallet

        //give owner all token supply
        emit Transfer(address(0), owner(), _tTotal);
    }

    //** ********** Misc
    //to recieve ETH from uniswapV2Router when swapping
    receive() external payable {}

    // ********** Overrides of IERC20Metadata interface
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    // ********** Overrides of IERC20 interface
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];

        return tokenFromReflection(_rOwned[account]);
    }

    // ********** Overrides of ERC20 implementation
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        //TODO: check what this does,
        //but looks like if we are allowed to liquify our tokens on uniswap (PCS on BSC)
        //it will if we have more than the number of tokens to sell  to add to the liquidity...
        //basically (?): do we have enough liquidity to back the transfer?
        bool overMinTokenBalance =
            contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify && //if we are not in `swapAndLiquify` (useful to avoid cycle calls)
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fees
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        uint256 extraLiquidityFee = 0;
        /*
        //selling token
        if (to == uniswapV2Pair) {

            //selling to token, add extra fee
            extraLiquidityFee = extraLiquidityFee.add(_extraLiquidityFeeOnSell);

            //start checks for anti dumping
            AntiDumpData storage antiDump = _antiDump[from];
            //if the time saved is past,
            //then the timer has expired and we can set a new one
            //as well as resetting the count
            if (antiDump.time < block.timestamp) {
                antiDump.time = block.timestamp.add(dumpPenaltyTimer);
                antiDump.count = 0;
            }

            //this is really important as otherwise we might end up
            //with a weird amount later when we do maxTokens - count!!
            //basically we don't want to do anything else if we have reached
            //the count in a previous transaction
            require(
                antiDump.count < numTokensMaxPerDumpPenaltyReset,
                "RACN: too many tokens sold in too little time"
            );

            //trying to sell above the allowed maximum per timer
            if (antiDump.count.add(amount) > numTokensMaxPerDumpPenaltyReset) {
                //set amount to maximum allowed before reaching limit
                amount = numTokensMaxPerDumpPenaltyReset.sub(antiDump.count);

                //set count to max so we always trigger this for the timer
                antiDump.count = numTokensMaxPerDumpPenaltyReset + 1;
                //set the timer to +`dumpPenaltyTimer`
                //instead of waiting natural occurrence
                antiDump.time = block.timestamp.add(dumpPenaltyTimer);
            }

            //trying to sell more than `numTokensDumpPenalty`
            //in a given timer
            //it will add the liquidity also if the previous if block was true (intended)
            if (antiDump.count.add(amount) > numTokensDumpPenalty) {
                //add fee

                //to be more fair and consistent we should be adding the fee
                //only on the tokens sold that would make the count more
                //than `numTokensDumpPenalty`...
                //ie:
                //current behavior means that if count is:
                //`numTokensDumpPenalty`- 1
                //if the next tx is biffer than 1, then this fee will activate
                //for the entire amount, not just 1 token, which would be what
                //exceeds `numTokensDumpPenalty`
                extraLiquidityFee = extraLiquidityFee.add(
                    _dumpPenaltyLiquidityFee
                );

                //increase counter by amount
                antiDump.count = antiDump.count.add(amount);
            }
        }
         */

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee, extraLiquidityFee);
    }

    // ************ Administration

    function excludeFromReward(address account) public onlyOwner {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(account != address(this)); //can't exclude contract address
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            //remove rewards and store in tokens owned
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                //if account is in _excluded
                _excluded[i] = _excluded[_excluded.length - 1]; //replace current excluded with last in list
                _tOwned[account] = 0; //reset number of _tOwned (??)
                _isExcluded[account] = false; //set mapping as included
                _excluded.pop(); //remove last (since we put it in i'th slot)
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

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        _liquidityFee = liquidityFee;
    }

    /*
    function setLiquidityFeeOnSellPercent(uint256 liquidityFeeOnSell) external onlyOwner {
        _extraLiquidityFeeOnSell = liquidityFeeOnSell;
    }

    function setDumpPenaltyLiquidityFeePercent(uint256 dumpPenaltyLiquidityFee) external onlyOwner {
        _dumpPenaltyLiquidityFee = dumpPenaltyLiquidityFee;
    }

    function setDumpPenaltyTimer(uint256 time) external onlyOwner {
        dumpPenaltyTimer = time;
    }

    function setNumTokensDumpPenalty(uint256 numTokens) external onlyOwner {
        numTokensDumpPenalty = numTokens;
    }

    function setNumTokensMaxPerDumpPenaltyReset(uint256 numTokens) external onlyOwner {
        numTokensMaxPerDumpPenaltyReset = numTokens;
    }
     */

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    function setTeamWallet(address newWallet) external onlyOwner {
        devWallet = newWallet;
    }

    //If we have a presale we'll need to call this function after finalizing the presale and set the initial fees to 0 - CHANGEME
    function enableAllFees() external onlyOwner {
        _taxFee = 4;
        _previousTaxFee = _taxFee;

        _liquidityFee = 4;
        _previousLiquidityFee = _liquidityFee;

        _devFee = 2;
        _previousDevFee = _devFee;

        /*
        _extraLiquidityFeeOnSell = 2;
        _previousExtraLiquidityFeeOnSell = _extraLiquidityFeeOnSell;

        _dumpPenaltyLiquidityFee = 5;
        _previousDumpPenaltyLiquidityFee = _dumpPenaltyLiquidityFee;
         */

        setSwapAndLiquifyEnabled(true);
    }

    // ************* Math
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        public
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

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    //takes total amount to transfer
    //returns (rewardAmount, rewardTrasnferAmount, rewardFee, tokenTransferAmount, tokenFee, liquidityFee)
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
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity) =
            _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) =
            _getRValues(tAmount, tFee, tLiquidity, _getRate());
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    //takes total amount to transfer
    //and returns (actualAmount, txFee, liquidityFee)
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

    //takes the total amount to transfer, the txFee, the liquidityFee and the current rate
    //returns (rewardAmount, rewardTransferAmount, rewardFee)
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

    //returns rate? rate of rewards to tokens
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        //decrease rSupply and tSupply by each `excluded`'s amount
        //probably because these accounts don't count in the rewardSupply and tokenSupply
        for (uint256 i = 0; i < _excluded.length; i++) {
            //return actual _rTotal and _tTotal in case the coins from the excluded people are greater than the current count
            //not sure why tho...
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            //decerese supply by owned amounts
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        //if reward supply is less than calcualted rewardTotal / calculatedTotal
        //then return actual _rTotal and _tTotal
        //again, not sure why...
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    //from the calcualted token liquidity
    function _takeLiquidity(uint256 tLiquidity) private {
        uint256 currentRate = _getRate();
        //get the rewardLiquidity (token*rate)
        uint256 rLiquidity = tLiquidity.mul(currentRate);

        //and add to the contract's reward total
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        //but if we are excluded from the rewards, then we add to the token total
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    //returns the tax fee amount. _taxFee is a %
    //amount: 100 = x : _taxFee
    //100 * x = amount * _taxFee =>
    //x = (amount * _taxFee) / 100
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(100);
    }

    //same as above
    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(100);
    }

    //sets all fees to 0, but makes a backup in _previous*
    //if fees are already 0, does nothing
    function removeAllFee() private {
        if (
            _taxFee == 0 &&
            _liquidityFee == 0 &&
            _devFee == 0
            /*
            && _extraLiquidityFeeOnSell == 0 &&
            _dumpPenaltyLiquidityFee == 0
             */
        ) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousDevFee = _devFee;
        /*
        _previousExtraLiquidityFeeOnSell = _extraLiquidityFeeOnSell;
        _previousDumpPenaltyLiquidityFee = _dumpPenaltyLiquidityFee;
         */

        _taxFee = 0;
        _liquidityFee = 0;
        _devFee = 0;
        /*
        _extraLiquidityFeeOnSell = 0;
        _dumpPenaltyLiquidityFee = 0;
         */
    }

    //does the opposite of the above
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
        _devFee = _previousDevFee;
        /*
        _extraLiquidityFeeOnSell = _previousExtraLiquidityFeeOnSell;
        _dumpPenaltyLiquidityFee = _previousDumpPenaltyLiquidityFee;
         */
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    //**************** Liquidity management (on-demand)

    //this will split in half the provided amount
    //the first half will be converted to ETH (or BNB)
    //and this ETH + secondHalf will be put as liquidity on uniswap
    //the function is called around `lockTheSwap` so we are aware if we are in this function
    //in other calls
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> TOKEN swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        //approve transfer of tokenAmount in uniswap
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path, //this is the path to take, in this case TOKEN -> WETH
            address(this), //where to send the ETH
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this), //token address
            tokenAmount, //amount
            0, // slippage is unavoidable, tokenMmin
            0, // slippage is unavoidable, ethMIN
            owner(), //who to send the liquidity tokens
            block.timestamp
        );
    }

    //*********** Token transfer implementations

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee,
        uint256 extraLiquidityFee
    ) private {
        if (!takeFee) removeAllFee();

        //Calculate team amount
        //again, devFee is %
        uint256 devAmt = amount.mul(_devFee).div(100);
        uint256 feeReducedAmount = amount.sub(devAmt); //so amount - devFee

        //store liquidity fee temporarily
        uint256 _tempLiquidityFee = _liquidityFee;
        //and add increase to liquidityFee
        _liquidityFee = _liquidityFee.add(extraLiquidityFee);

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, feeReducedAmount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, feeReducedAmount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, feeReducedAmount);
        } else {
            _transferStandard(sender, recipient, feeReducedAmount);
        }

        //Temporarily remove fees to transfer to marketing and team wallets
        //Can't be sure that the _previous fees are the same as the current fees so need to back them up temporarily
        uint256 _tempTaxFee = _taxFee;
        _taxFee = 0;
        _liquidityFee = 0;

        //Send transfers to team wallet (if there's anything to send)

        if (devAmt > 0) _transferStandard(sender, devWallet, devAmt);

        //Restore tax and liquidity fees
        _taxFee = _tempTaxFee;
        _liquidityFee = _tempLiquidityFee;

        if (!takeFee) restoreAllFee();
    }

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
        _rOwned[sender] = _rOwned[sender].sub(rAmount); //remove rewardTokens from sender
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount); //add rewardTokens to receiver
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
        //add both rewardTokens and normalTokens to the receiver
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
        //remove rewardTokens and normalTokens to the sender
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        //and add to the receiver the rewardTokens
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
        _tOwned[sender] = _tOwned[sender].sub(tAmount); //remove token amount from sender
        _rOwned[sender] = _rOwned[sender].sub(rAmount); //remove reward amount from sender
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount); //add transferred amount tokens to receiver (amount - fees)
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount); //add reward amount tokens to receiver (amount - fees)
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}