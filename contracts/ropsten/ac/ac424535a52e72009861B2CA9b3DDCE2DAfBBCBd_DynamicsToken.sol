// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import './utils/Ownable.sol';
import "./utils/LockableSwap.sol";
import "./utils/EthReflectingToken.sol";
import "./libs/SwapWithLP.sol";
import "./libs/FeeLibrary.sol";

contract DynamicsToken is Context, Ownable, IERC20, LockableSwap, FeeLibrary, EthReflectingToken {
    using SafeMath for uint256;
    using Address for address;

    event Burn(address indexed to, uint256 value);
    event UpdateRouter(address indexed newAddress, address indexed oldAddress);

    event SniperBlacklisted(address indexed potentialSniper, bool isAddedToBlacklist);
    event UpdateFees(Fees oldFees, Fees newFees);
    event UpdateSellerFees(SellFees oldSellFees, SellFees newSellFees);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event BuyBackTriggered(uint256 ethSpent);

    struct User {
        uint256 buyCD;
        uint256 sellCD;
        uint256 lastBuy;
        bool exists;
    }
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    Fees public buyFees = Fees({reflection: 3, project: 3, liquidity: 2, burn: 2, marketing: 1, ethReflection: 0});
    Fees public transferFees = Fees({reflection: 1, project: 1, liquidity: 1, burn: 0, marketing: 0, ethReflection: 0});

    Fees private previousBuyFees;
    Fees private previousTransferFees;

    // To lock the init after first run as constructor is split into that function and we dont want to be able to ever run it twice
    uint8 private runOnce = 2;

    uint256 public minGas = 200000;

    uint256 public totalEthSentToPool = 0;

    uint256 private buyerDiscountPrice = 2 ether;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => User) private trader;
    mapping (address => bool) public _isBlacklisted;
    mapping (address => bool) public _isExcludedFromFee;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    // TODO - Private at launch
    EthBuybacks public buybackTokenTracker = EthBuybacks({liquidity : 0, redistribution : 0, buyback : 0});

    uint256 private sellToProject = 40;
    uint256 private sellToEthReflections = 40;

    uint256 public _minimumTimeFee = 5;
    uint256 public _minimumSizeFee = 5;

    address public buybackSinkAddress;
    bool public buyBackEnabled = true;
    uint256 public minBuyBack = 0.1 ether;
    uint256 public maxBuyBack = 0.5 ether;

    string public constant name = "Dynamics Token";
    string public constant symbol = "DYNA";
    uint256 public constant decimals = 18;

    bool private sniperDetection = true;

    bool public tradingOpen = false;
    bool public _cooldownEnabled = false; // TODO - True for prod

    uint256 private tradingStartTime;

    uint256 public _maxTxAmount;
    address payable public _projectWallet;
    address payable public _marketingWallet;
    address payable public _charityWallet;

    uint256 public numTokensSellToAddToLiquidity;

    constructor (uint256 _supply, uint256 _MAXTXAMOUNT, uint256 ADDTOLIQUIDITYTHRESHOLD,
        address routerAddress, address tokenOwner, address projectWallet, address marketingWallet) payable {
        _tTotal = _supply * 10 ** decimals;
        _rTotal = (MAX - (MAX % _tTotal));
        _maxTxAmount = _MAXTXAMOUNT * 10 ** decimals;
        numTokensSellToAddToLiquidity = ADDTOLIQUIDITYTHRESHOLD * 10 ** decimals;
        _projectWallet = payable(projectWallet);
        _marketingWallet = payable(marketingWallet);

        uniswapV2Router = IUniswapV2Router02(routerAddress);

        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(_projectWallet)] = true;
        _isExcludedFromFee[address(_charityWallet)] = true;
        buybackSinkAddress = address(tokenOwner);
        _owner = _msgSender();
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
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

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromFee(address account, bool exclude) public onlyOwner {
        _isExcludedFromFee[account] = exclude;
    }

    function setMaxTx(uint256 maxTx) public onlyOwner {
        _maxTxAmount = maxTx  * 10 ** decimals;
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _takeProjectFees(uint256 tProject, uint256 tMarketing) private {
        if(tProject == 0 && tMarketing == 0)
            return;
        uint256 currentRate =  _getRate();
        uint256 rProject = tProject.mul(currentRate);
        uint256 rMarketing = tMarketing.mul(currentRate);

        _rOwned[_projectWallet] = _rOwned[_projectWallet].add(rProject);
        _rOwned[_marketingWallet] = _rOwned[_marketingWallet].add(rMarketing);
    }

    function _getTValues(uint256 tAmount, uint256 liquidityFee, uint256 reflectiveFee, uint256 nonReflectiveFee) private pure returns (uint256, uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(reflectiveFee).div(100);
        uint256 tLiquidity = tAmount.mul(liquidityFee).div(100);
        uint256 tOtherFees = tAmount.mul(nonReflectiveFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        tTransferAmount = tAmount.sub(tLiquidity).sub(tOtherFees);
        return (tTransferAmount, tFee, tLiquidity, tOtherFees);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tLiquidity, uint256 tOtherFees, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rOtherFees = tOtherFees.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity).sub(rOtherFees);
        return (rAmount, rTransferAmount, rFee);
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

    function _takeLiquidity(uint256 tLiquidity) internal {
        if(tLiquidity == 0)
            return;
        uint256 currentRate =  _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        buybackTokenTracker.liquidity = buybackTokenTracker.liquidity.add(rLiquidity);
    }

    function _takeEthBasedFees(uint256 tRedistribution, uint256 tBuyback) private {
        uint256 currentRate =  _getRate();
        if(tRedistribution > 0){
            uint256 rRedistribution = tRedistribution.mul(currentRate);
            _rOwned[address(this)] = _rOwned[address(this)].add(rRedistribution);
            buybackTokenTracker.redistribution = buybackTokenTracker.redistribution.add(rRedistribution);
        }
        if(tBuyback > 0){
            uint256 rBuyback = tBuyback.mul(currentRate);
            _rOwned[address(this)] = _rOwned[address(this)].add(rBuyback);
            buybackTokenTracker.buyback = buybackTokenTracker.buyback.add(rBuyback);
        }
    }

    function removeAllFee() private {
        setFrom(previousBuyFees, buyFees);
        previousTransferFees = transferFees;
        setFrom(previousSellFees, sellFees);

        setToZero(buyFees);
        setToZero(transferFees);
        setToZero(sellFees);
    }

    function restoreAllFee() private {
        setFrom(buyFees, previousBuyFees);
        transferFees = previousTransferFees;
        setFrom(sellFees, previousSellFees);
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    // This function was so large given the fee structure it had to be subdivided as solidity did not support
    // the possibility of containing so many local variables in a single execution.
    function _transfer(address from, address to, uint256 amount) private {
        require(gasleft() >= minGas, "This transaction requires more gas to complete");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 rAmount;
        uint256 tTransferAmount;
        uint256 rTransferAmount;

        bool takeFee = !(_isExcludedFromFee[from] || _isExcludedFromFee[to]);
        if(!takeFee){
            removeAllFee();
        }
        if(from != owner() && to != owner()) {
            require(!_isBlacklisted[to] && !_isBlacklisted[from], "Address is blacklisted");

            if(!trader[from].exists) {
                trader[from] = User(0,0,0,true);
            }
            if(!trader[to].exists) {
                trader[to] = User(0,0,0,true);
            }

            if(from == uniswapV2Pair || from == address(uniswapV2Router)) {  // Buy
                (rAmount, tTransferAmount, rTransferAmount) = calculateBuy(to, amount);
            } else if(to == uniswapV2Pair || to == address(uniswapV2Router)) {  // Sell
                (rAmount, tTransferAmount, rTransferAmount) = calculateSell(from, amount);
            } else {  // Transfer
                (rAmount, tTransferAmount, rTransferAmount) = calculateTransfer(to, amount);
            }
            if(!inSwapAndLiquify && from != uniswapV2Pair)
                selectSwapEvent();

        } else {
            rAmount = amount.mul(_getRate());
            tTransferAmount = amount;
            rTransferAmount = rAmount;
        }

        if(!takeFee){
            restoreAllFee();
        }
        _transferStandard(from, to, rAmount, tTransferAmount, rTransferAmount);
    }

    function selectSwapEvent() private lockTheSwap {
        uint256 contractTokenBalance;
        // BuyBack Event
        if(buyBackEnabled && address(this).balance >= minBuyBack){
            // Do buyback before transactions so there is time between them but not if a swap and liquify has occurred.
            buyBackTokens(address(this).balance);
        } else if(buybackTokenTracker.redistribution.add(buybackTokenTracker.buyback) > numTokensSellToAddToLiquidity){
        // Swap for Eth Event

            (uint256 reflectionsEth) = swapEthBasedFees(buybackTokenTracker.redistribution, buybackTokenTracker.buyback);
            totalEthSentToPool = totalEthSentToPool.add(reflectionsEth);
        } else if(buybackTokenTracker.liquidity > numTokensSellToAddToLiquidity){
        // LP Swap Event
            contractTokenBalance = buybackTokenTracker.liquidity;

            if(contractTokenBalance >= _maxTxAmount)
            {
                contractTokenBalance = _maxTxAmount;
            }
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        } else if(automatedReflectionsEnabled) {
        // Automated Reflection Event
            reflectRewards();
        }
    }

    function calculateBuy(address to, uint256 amount) private returns(uint256 rAmount , uint256 tTransferAmount, uint256 rTransferAmount){
        require(tradingOpen || sniperDetection, "Trading not yet enabled.");
        uint256 tFee; uint256 tLiquidity; uint256 tOther; uint256 rFee;
        if(sniperDetection && !tradingOpen){ // Pre-launch snipers get nothing but a blacklisting
            _isBlacklisted[to] = true;

            emit SniperBlacklisted(to, true);

            to = address(this);
            rAmount = amount.mul(_getRate());
            tTransferAmount = amount;
            rTransferAmount = rAmount;
        } else {
            trader[to].lastBuy = block.timestamp;

            if(_cooldownEnabled) {
                if(block.timestamp < tradingStartTime + 6 hours){
                    require(msg.value <= 3 ether, "Purchase too large for initial opening hours");
                } else {
                    require(trader[to].buyCD < block.timestamp, "Your buy cooldown has not expired.");
                    trader[to].buyCD = block.timestamp + (15 seconds);
                }
                trader[to].sellCD = block.timestamp + (15 seconds);
            }

            uint256 nonReflectiveFee = buyFees.burn.add(buyFees.project).add(buyFees.marketing).add(buyFees.ethReflection);

            (tTransferAmount, tFee, tLiquidity, tOther) = _getTValues(amount, buyFees.liquidity, buyFees.reflection, nonReflectiveFee);

            // Large buy fee discount
            if(msg.value >= buyerDiscountPrice){
                tFee = tFee.div(2);
                tLiquidity =tLiquidity.div(2);
                tOther = tOther.div(2);
                tTransferAmount = tTransferAmount.add(tOther).add(tLiquidity).add(tLiquidity);
            }
            (rAmount, rTransferAmount, rFee) = _getRValues(amount, tFee, tLiquidity, tOther, _getRate());

            _takeLiquidity(tLiquidity);
            _burn(tOther.mul(buyFees.burn).div(nonReflectiveFee));
            _takeProjectFees(tOther.mul(buyFees.project).div(nonReflectiveFee), tOther.mul(buyFees.marketing).div(nonReflectiveFee));
            _takeEthBasedFees(tOther.mul(buyFees.ethReflection).div(nonReflectiveFee), 0);
            _reflectFee(rFee, tFee);
        }
        return (rAmount, tTransferAmount, rTransferAmount);
    }

    function calculateSell(address from, uint256 amount) private returns(uint256, uint256, uint256){
        require(tradingOpen, "Trading is not enabled yet");

        if(_cooldownEnabled) {
            require(trader[from].sellCD < block.timestamp, "Your sell cooldown has not expired.");
            require(block.timestamp > tradingStartTime + 3 minutes); // Reset for main
        }

        // Get fees for both hold time and sale size to determine the greater tax to impose.
        uint256 timeBasedFee = _minimumTimeFee;
        uint256 lastBuy = trader[from].lastBuy;
        if(block.timestamp > lastBuy.add(sellFees.level[5].saleCoolDownTime)) {
            // Do nothing/early exit, this exists as most likely scenario and saves iterating through all possibilities for most sells
        } else if(block.timestamp < lastBuy.add(sellFees.level[1].saleCoolDownTime)) {
            timeBasedFee = sellFees.level[1].saleCoolDownFee;
        } else if(block.timestamp < lastBuy.add(sellFees.level[2].saleCoolDownTime)) {
            timeBasedFee = sellFees.level[2].saleCoolDownFee;
        } else if(block.timestamp < lastBuy.add(sellFees.level[3].saleCoolDownTime)) {
            timeBasedFee = sellFees.level[3].saleCoolDownFee;
        } else if(block.timestamp < lastBuy.add(sellFees.level[4].saleCoolDownTime)) {
            timeBasedFee = sellFees.level[4].saleCoolDownFee;
        } else if(block.timestamp < lastBuy.add(sellFees.level[5].saleCoolDownTime)) {
            timeBasedFee = sellFees.level[5].saleCoolDownFee;
        }

        // TODO Reverse order maybe?
        uint256 finalSaleFee = _minimumSizeFee;
        uint256 poolSize = amountInPool();
        if(amount < poolSize.mul(sellFees.level[5].saleSizeLimitPercent).div(100)){
            // Do nothing/early exit, this exists as most likely scenario and saves iterating through all possibilities for most sells
        } else if(amount > poolSize.mul(sellFees.level[1].saleSizeLimitPercent).div(100)) {
            finalSaleFee = sellFees.level[1].saleSizeLimitPrice;
        } else if(amount > poolSize.mul(sellFees.level[2].saleSizeLimitPercent).div(100)) {
            finalSaleFee = sellFees.level[2].saleSizeLimitPrice;
        } else if(amount > poolSize.mul(sellFees.level[3].saleSizeLimitPercent).div(100)) {
            finalSaleFee = sellFees.level[3].saleSizeLimitPrice;
        } else if(amount > poolSize.mul(sellFees.level[4].saleSizeLimitPercent).div(100)) {
            finalSaleFee = sellFees.level[4].saleSizeLimitPrice;
        } else if(amount > poolSize.mul(sellFees.level[5].saleSizeLimitPercent).div(100)) {
            finalSaleFee = sellFees.level[5].saleSizeLimitPrice;
        }

        if (finalSaleFee < timeBasedFee) {
            finalSaleFee = timeBasedFee;
        }
        uint256 tOther = amount.mul(finalSaleFee).div(100);
        uint256 tTransferAmount = amount.sub(tOther);

        uint256 rAmount = amount.mul(_getRate());
        uint256 rTransferAmount = tTransferAmount.mul(_getRate());

        uint256 teamQty = tOther.mul(sellToProject).div(100);
        uint256 ethRedisQty = tOther.mul(sellToEthReflections).div(100);
        uint256 buyBackQty = tOther.sub(teamQty).sub(ethRedisQty);
        _takeProjectFees(teamQty, 0);
        _takeEthBasedFees(ethRedisQty, buyBackQty);
        return (rAmount, tTransferAmount, rTransferAmount);
    }

    function calculateTransfer(address to, uint256 amount) private returns(uint256, uint256, uint256){
        uint256 rAmount;
        uint256 tTransferAmount;
        uint256 rTransferAmount;
        uint256 tFee;
        uint256 tLiquidity;
        uint256 tOther;
        uint256 rFee;
        trader[to].lastBuy = block.timestamp;

        uint256 nonReflectiveFee = transferFees.burn.add(buyFees.project).add(transferFees.marketing).add(transferFees.ethReflection);

        (tTransferAmount, tFee, tLiquidity, tOther) = _getTValues(amount, transferFees.liquidity, transferFees.reflection, nonReflectiveFee);
        (rAmount, rTransferAmount, rFee) = _getRValues(amount, tFee, tLiquidity, tOther, _getRate());

        _takeLiquidity(tLiquidity);
        _burn(tOther.mul(transferFees.burn).div(nonReflectiveFee));
        _takeProjectFees(tOther.mul(transferFees.project).div(nonReflectiveFee), tOther.mul(transferFees.marketing).div(nonReflectiveFee));
        _takeEthBasedFees(tOther.mul(transferFees.ethReflection).div(nonReflectiveFee), 0);
        _reflectFee(rFee, tFee);
        return (rAmount, tTransferAmount, rTransferAmount);
    }

    function _transferStandard(address sender, address recipient, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
        if(sender != address(0))
            _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        emit Transfer(sender, recipient, tTransferAmount);
        try reflectionContract.logTransactionEvent{gas: gasleft()}(sender, _rOwned[sender], recipient, _rOwned[recipient]) {} catch {
            address(reflectionContract).call{gas: gasleft()}(abi.encodeWithSignature("logTransactionEvent(address, uint256, address, uint256)",sender, _rOwned[sender], recipient, _rOwned[recipient]));
        }
    }

    function burn(uint256 amount) external {
        if(amount == 0)
            return;
        uint256 currentRate = _getRate();
        uint256 rAmount = amount.mul(currentRate);
        _rOwned[_msgSender()] = _rOwned[_msgSender()].sub(rAmount);
        _burn(amount);
    }

    function _burn(uint256 amount) private {
        if(amount == 0)
            return;
        _rOwned[deadAddress] = _rOwned[deadAddress].add(amount.mul(_getRate()));
        emit Burn(address(deadAddress), amount);
    }

    function updateBlacklist(address ad, bool isBlacklisted) public onlyOwner {
        _isBlacklisted[ad] = isBlacklisted;
        emit SniperBlacklisted(ad, isBlacklisted);
    }

    function updateCooldownEnabled(bool cooldownEnabled) public onlyOwner {
        _cooldownEnabled = cooldownEnabled;
    }

    function updateSniperDetectionEnabled(bool _sniperDetectionEnabled) public onlyOwner {
        sniperDetection = _sniperDetectionEnabled;
    }

    function updateBuyerFees(uint256 reflectionFee, uint256 projectFee, uint256 liquidityFee, uint256 burnFee, uint256 marketingFee, uint256 ethReflectionFee) public onlyOwner {
        Fees memory oldBuyFees = buyFees;
        setTo(buyFees, reflectionFee, projectFee, liquidityFee, burnFee, marketingFee, ethReflectionFee);
        emit UpdateFees(oldBuyFees, buyFees);
    }

    function updateTransferFees(uint256 reflectionFee, uint256 projectFee, uint256 liquidityFee, uint256 burnFee, uint256 marketingFee, uint256 ethReflectionFee) public onlyOwner {
        Fees memory oldTransferFees = transferFees;
        setTo(transferFees, reflectionFee, projectFee, liquidityFee, burnFee, marketingFee, ethReflectionFee);
        emit UpdateFees(oldTransferFees, transferFees);
    }

    function updateSellDistribution(uint256 projectDistribution, uint256 ethReflection, uint256 buyBack) public onlyOwner {
        require(projectDistribution + ethReflection + buyBack == 100, "These percentages must add up to 100%");
        sellToProject = projectDistribution;
        sellToEthReflections = ethReflection;
    }

    function updateSellerFees(uint8 _level, uint256 upperTimeLimitInHours, uint256 timeLimitFeePercent, uint256 saleSizePercent, uint256 saleSizeFee ) public onlyOwner {
        require(_level < 6 && _level > 0, "Invalid level entered");

        SellFees memory oldSellFees = sellFees.level[_level];
        setTo(sellFees.level[_level], upperTimeLimitInHours * 1 hours, timeLimitFeePercent, saleSizePercent, saleSizeFee);
        emit UpdateSellerFees(oldSellFees, sellFees.level[_level]);
    }

    function updateFallbackFees(uint256 minimumTimeBasedFee, uint256 minimumSizeBasedFee) public onlyOwner {
        _minimumTimeFee = minimumTimeBasedFee;
        _minimumSizeFee = minimumSizeBasedFee;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function swapAndLiquify(uint256 contractTokenBalance) private {
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);
        buybackTokenTracker.liquidity = buybackTokenTracker.liquidity.sub(contractTokenBalance);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;
        _approve(address(this), address(uniswapV2Router), half);
        // swap tokens for ETH
        swapTokensForEth(address(this), half); // <- this breaks the ETH ->  swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        _approve(address(this), address(uniswapV2Router), otherHalf);
        addLiquidity(address(this), otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(address destination, uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            destination,
            block.timestamp
        );
    }

    function swapETHForTokens(uint256 amount, address destination) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        if(amount > address(this).balance){
            amount = address(this).balance;
        }

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            destination, // Burn address
            block.timestamp.add(300)
        );

    }

    function addLiquidity(address destination, uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            destination,
            block.timestamp
        );
    }

    function swapEthBasedFees(uint256 reflections, uint256 buyback) private returns(uint256 ethForReflections){
        uint256 initialBalance = address(this).balance;
        _approve(address(this), address(uniswapV2Router), reflections.add(buyback));
        // swap tokens for ETH
        swapTokensForEth(address(this), reflections.add(buyback)); // <- this breaks the ETH ->  swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);
        if(buyback > 0){
            ethForReflections = newBalance.mul(reflections).div(buyback);
        } else {
            ethForReflections = newBalance;
        }
        buybackTokenTracker.redistribution = buybackTokenTracker.redistribution.sub(reflections);
        buybackTokenTracker.buyback = buybackTokenTracker.buyback.sub(buyback);
        takeEthReflection(ethForReflections);
    }

    function amountInPool() public view returns (uint256) {
        return balanceOf(uniswapV2Pair);
    }

    function setNumTokensSellToAddToLiquidity(uint256 swapNumber) public onlyOwner {
        numTokensSellToAddToLiquidity = swapNumber * 10 ** decimals;
    }

    function openTrading() public onlyOwner {
        tradingOpen = true;
        tradingStartTime = block.timestamp;
        swapAndLiquifyEnabled = true;
        if(balanceOf(address(this)) > 0 && amountInPool() > 0)
            swapAndLiquify(balanceOf(address(this)));
    }

    function updateRouter(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        emit UpdateRouter(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }

    function updateLPPair(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Pair), "This pair is already in use");
        uniswapV2Pair = address(newAddress);
    }

    function buyBackTokens(uint256 amount) private {
        if (amount > minBuyBack && amount < address(this).balance) {
            if(amount > maxBuyBack)
                amount = maxBuyBack;
            swapETHForTokens(amount, buybackSinkAddress);
        }
        emit BuyBackTriggered(amount);
    }

    function setBuyBackEnabled(bool _enabled) public onlyOwner {
        buyBackEnabled = _enabled;
    }

    function setBuyBackRange(uint256 _minBuyBackEther, uint256 _maxBuyBackEther) public onlyOwner {
        minBuyBack = _minBuyBackEther * 1 ether;
        maxBuyBack = _maxBuyBackEther * 1 ether;
    }

    function updateBuybackSink(address _sinkAddress) public onlyOwner {
        buybackSinkAddress = _sinkAddress;
    }

    function initMint(uint256[] memory values, address ownerAddress) external onlyOwner {
        require(runOnce == 2, "This function can only ever be called once");
        uint256 sentTotal = 0;
        uint256 xferVal = 0;
        address[54] memory addresses = [0x0fE3E2826827CC859773833111f68F585e4a834a,0xe3Ed76b866F904bb0a095A38F9B3d9c182e4b466,0x2C5d02977eC1C73e818FE7523bD36D639E605b64,0xb5B5642bdf1Bfd9E4cF27ca280fF48D807a45F10,0x4B0a629dc737646Fd157e63C34771d224c49e0Cf,0x6e61665eb04E6229138df2b4c6d4A5c9606f6C0a,0xD7212fcB56DfF5f49f4aa46735B2407e195Bbb9E,0xFD1673d13270C1d33ce518b12fAbA9626368a753,0xD609981CAdE9FEC3Dc760326E8826D100Af86272,0x3880ECe41a29542c58eee6D7727E03F290C51529,0x94EC44cfa9822510ddd784F1Fc936260b10Ba215,0x1a25c19416d725aA5C03116C3D43604D93ee01F9,0x2ced5e2Def911DF456E7A486BcC0e5C700b2d8b2,0x33c01ff156A72881d3A2C8D07561C325DBb10DDA,0xcFbA019149Af2Ab7A3e65DC90f4FE8b1eEF1c73E,0xa8361c07Ba63A9ECaec7B6B3881F505d741F6860,0x3E13113a796e7AD47dccFA862A0a76Fd25F27cE9,0x1D347a30eFA7983B3CaAC0886C4275DdC38d7922,0xd39040606B55029e8195509858F76fe1fE1f2359,0x1b1837E0D1D95d865621B96B9f4D52da4E2EAe0e,0xC3eBA2E575D2c4048E20722DbDD88A62879B2eB0,0xe9BA6fB8cbEEa8276D55745F3f173aA9B49d1b36,0x97598181D041343D9Ac718a11a2F0D8266aBC17C,0x46969b1F22C00B89493BbB9576A26d0a7F9964c1,0x2AA102Aff74e54A52d67c1a28827013ca88d9F32,0x1d3C2919E3C6a7edfd58812F1543DA10fc66e95e,0x9351b6C5e9c32Ee29b1D1EB2FB64232c1DCa7CA2,0x8130083E8758F87ed9ea3eC428829dA03672fF27,0x992BE87d227C4017C27aFCAeC2e10BD962fa54d1,0x3e8B52Cf4C4Ed05AF3186fBde21e512A3FDb9aef,0x41B7F3C8dD9609a80b9B2b31d40e6d03b4A4F8ce,0x41b0352c46e4fAe034C4bE7b1761Ded202C724DA,0x8d1e6874446d9d478AE1a5e6327Afe074f95dE7a,0x9863a19eD513FC01F8eAeFcbdf8DFC2eAe33D349,0x43a38ab04ee663893484675ce8054F0865fb5bcC,0xc917Caf03F4a777b223835D2649C0EC02D64440B,0x6fb01e3Ce1414a2F1ac19851560F335DD06D75cf,0xC7B3158EE3de98c0c48A718cc6B2169bBe2FdcdE,0xfF86ac28DBc3720b3B40D7860FF048df30328b16,0x9714CD7170F4926725Db3B71881590587C424b41,0x6a99D086Cb1935aA67ee94b554ce096d59ab4dB2,0x343f6051A6ECaF68E4C0322b2dcD3C22D7F19B0f,0xc7Cc496a2766C6e2D16e522d2F95451C13999854,0xE30a6B5817eB97Ad31d13f05fCc00D2be4dD0f15,0x5F82704B30a8d0aBe3CE85cF26aB681f2Dd4430B,0x653aAc8a51Cc7655625e7D09683C8C5BadCfcC18,0x40b15ec54089686A03D08cf3E7D5db0008C16293,0xd80c2A85264B4F0e9a2b5855Dd7DA3a6b7c3B7a1,0xb03932dbA887ABB55Dc22fd319B07EF3116E87D9,0x498c5b2CDda547fF4953c95d979506cE56b4d724,0x30602ee8ff5Edb495F52774DF4F1fDB7b65a71f4,0x9e80DEDd460f54c0E0e8b4bf23403D470fA8ecD9,0x855B455B08095AEf99eC151e4051fD32D1d61631,0xD2Ed0c778ba9D1679E98cc516E26C93ba4F9179c];
        for(uint256 i = 0; i < addresses.length; i++){
            xferVal = uint256(values[i]).mul(10 ** 18);
            _rOwned[address(addresses[i])] = xferVal.mul(_getRate());
            emit Transfer(address(this), addresses[i], xferVal);
            sentTotal = sentTotal.add(xferVal);
        }
        if(sentTotal > _tTotal)
            revert();
        xferVal = _tTotal.sub(sentTotal);
        _rOwned[address(ownerAddress)] = xferVal.mul(_getRate());
        runOnce = 1;
    }

    function init(address reflectorAddress) public onlyOwner{
        require(runOnce == 1, "This function can only ever be called once");
        reflectionContract = IAutomatedExternalReflector(payable(reflectorAddress));
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        // set the rest of the contract variables
        initSellFees();
        openTrading();  // TODO Remove for mainnet
        runOnce = 0;
    }

    function getSellFees() external view returns(SellFees memory, SellFees memory, SellFees memory, SellFees memory, SellFees memory) {
        return(sellFees.level[1], sellFees.level[2], sellFees.level[3], sellFees.level[4], sellFees.level[5]);
    }

    function depositTokens(uint256 liquidityDeposit, uint256 redistributionDeposit, uint256 buybackDeposit) public {
        require(balanceOf(_msgSender()) >= liquidityDeposit.add(redistributionDeposit).add(buybackDeposit), "You do not have the balance to performe this action");
        uint256 totalDeposit = liquidityDeposit.add(redistributionDeposit).add(buybackDeposit);
        uint256 rAmountDeposit = totalDeposit.mul(_getRate());
        _transferStandard(_msgSender(), address(this), rAmountDeposit, totalDeposit, rAmountDeposit);
    }

    function updateMinGas(uint256 minGasQuantity) public onlyOwner {
        require(minGas >= 200000, "Minimum Gas must be over 200,000");
        minGas = minGasQuantity;
    }
}