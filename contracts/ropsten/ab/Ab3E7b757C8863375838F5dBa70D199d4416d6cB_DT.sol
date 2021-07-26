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

contract DT is Context, Ownable, IERC20, LockableSwap, SwapWithLP, FeeLibrary, EthReflectingToken {
    using SafeMath for uint256;
    using Address for address;

    event Burn(address indexed to, uint256 value);

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

    Fees public buyFees = Fees({reflection: 3, project: 3, liquidity: 2, burn: 2, marketing: 1, ethReflection: 0});
    Fees public transferFees = Fees({reflection: 1, project: 1, liquidity: 1, burn: 0, marketing: 0, ethReflection: 0});

    Fees private previousBuyFees;
    Fees private previousTransferFees;

    // To lock the init after first run as constructor is split into that function and we dont want to be able to ever run it twice
    uint8 private runOnce = 1;

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

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;

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

    uint256 public sellFeeLevels = 5;

    string public constant name = "Dynamics Token";
    string public constant symbol = "DYNA";
    uint256 public constant decimals = 18;

    bool public sniperDetection = true;

    bool public tradingOpen = false;
    bool public _cooldownEnabled = false; // TODO - True for prod

    uint256 private tradingStartTime;

    uint256 public _maxTxAmount;
    address payable public _projectWallet;
    address payable public _marketingWallet;

    uint256 public numTokensSellToAddToLiquidity;

    constructor (string memory NAME, uint256 _supply, uint256 _MAXTXAMOUNT, uint256 ADDTOLIQUIDITYTHRESHOLD,
        address routerAddress, address tokenOwner, address projectWallet, address marketingWallet, address reflectorAddress) payable {
        _tTotal = _supply * 10 ** decimals;
        _rTotal = (MAX - (MAX % _tTotal));
        _maxTxAmount = _MAXTXAMOUNT * 10 ** decimals;
        numTokensSellToAddToLiquidity = ADDTOLIQUIDITYTHRESHOLD * 10 ** decimals;
        _projectWallet = payable(projectWallet);
        _marketingWallet = payable(marketingWallet);

        IAutomatedExternalReflector _reflectionContract = IAutomatedExternalReflector(payable(reflectorAddress));
        reflectionContract = _reflectionContract;

        _rOwned[tokenOwner] = _rTotal.div(2);
        _rOwned[msg.sender] = _rTotal.div(2);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress);
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        //exclude owner and this contract from fee
        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(_projectWallet)] = true;
        _isExcludedFromFee[address(_marketingWallet)] = true;
        buybackSinkAddress = address(this);
        _owner = tokenOwner;// msg.sender;
        emit Transfer(address(0), tokenOwner, _tTotal);
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

    function claimEthToProject() public {
        require(_msgSender() == owner() || _msgSender() == _projectWallet, "Account not authorized to call this function");
        payable(_projectWallet).transfer(address(this).balance);
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
        if(from != owner() && to != owner() && from != address(this) && to != address(this)) {
            require(!_isBlacklisted[to] && !_isBlacklisted[from], "Address is blacklisted");

            if(!trader[from].exists) {
                trader[from] = User(0,0,0,true);
            }
            if(!trader[to].exists) {
                trader[to] = User(0,0,0,true);
            }

            if(from == uniswapV2Pair && to != address(uniswapV2Router)) {  // Buy
                (rAmount, tTransferAmount, rTransferAmount) = calculateBuy(to, amount);
            } else if(from != uniswapV2Pair && from != address(uniswapV2Router) && to == uniswapV2Pair) {  // Sell
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

        _transferStandard(from, to, rAmount, tTransferAmount, rTransferAmount);
        if(!takeFee){
            restoreAllFee();
        }
    }

    function selectSwapEvent() private lockTheSwap {
        uint256 contractTokenBalance;
        // BuyBack Event
        if(buyBackEnabled && address(this).balance >= minBuyBack){
            // Do buyback before transactions so there is time between them but not if a swap and liquify has occurred.
            buyBackTokens(address(this).balance);
        } else
        // Swap for Eth Event
        if(buybackTokenTracker.redistribution.add(buybackTokenTracker.buyback) > numTokensSellToAddToLiquidity){
            (uint256 reflectionsEth) = swapEthBasedFees(buybackTokenTracker.redistribution, buybackTokenTracker.buyback);
            totalEthSentToPool = totalEthSentToPool.add(reflectionsEth);
        } else
        // LP Swap Event
        if(buybackTokenTracker.liquidity > numTokensSellToAddToLiquidity){
            contractTokenBalance = buybackTokenTracker.liquidity;

            if(contractTokenBalance >= _maxTxAmount)
            {
                contractTokenBalance = _maxTxAmount;
            }
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        } else
        // Automated Reflection Event
        if(automatedReflectionsEnabled) {
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
            // TODO - Clean this up
            burn(amount.mul(buyFees.burn).div(100));
            _takeProjectFees(amount.mul(buyFees.project).div(100), amount.mul(buyFees.marketing).div(100));
            _takeEthBasedFees(amount.mul(buyFees.ethReflection).div(100), 0);
            _reflectFee(rFee, tFee);
        }
    }

    function calculateSell(address from, uint256 amount) private returns(uint256 rAmount , uint256 tTransferAmount, uint256 rTransferAmount){
        require(tradingOpen, "Trading is not enabled yet");

        uint256 tOther;
        uint256 rFee;

        if(_cooldownEnabled) {
            require(trader[from].sellCD < block.timestamp, "Your sell cooldown has not expired.");
            require(block.timestamp > tradingStartTime + 3 hours);
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
        (tTransferAmount,,, tOther) = _getTValues(amount, 0, 0, finalSaleFee);
        (rAmount, rTransferAmount, rFee) = _getRValues(amount, 0, 0, tOther, _getRate());

        uint256 saleFeeQty = amount.mul(finalSaleFee).div(100);
        uint256 teamQty = saleFeeQty.mul(sellToProject).div(100);
        uint256 ethRedisQty = saleFeeQty.mul(sellToEthReflections).div(100);
        uint256 buyBackQty = saleFeeQty.sub(teamQty).sub(ethRedisQty);
        _takeProjectFees(teamQty, 0);
        _takeEthBasedFees(ethRedisQty, buyBackQty);
    }

    function calculateTransfer(address to, uint256 amount) private returns(uint256 rAmount , uint256 tTransferAmount, uint256 rTransferAmount){
        uint256 tFee; uint256 tLiquidity; uint256 tOther; uint256 rFee;
        trader[to].lastBuy = block.timestamp;

        uint256 nonReflectiveFee = buyFees.burn.add(buyFees.project).add(buyFees.marketing).add(buyFees.ethReflection);

        (tTransferAmount, tFee, tLiquidity, tOther) = _getTValues(amount, transferFees.liquidity, transferFees.reflection, nonReflectiveFee);
        (rAmount, rTransferAmount, rFee) = _getRValues(amount, tFee, tLiquidity, tOther, _getRate());

        _takeLiquidity(tLiquidity);
        burn(amount.mul(transferFees.burn).div(100));
        _takeProjectFees(amount.mul(transferFees.project).div(100), amount.mul(transferFees.marketing).div(100));
        _takeEthBasedFees(amount.mul(transferFees.ethReflection).div(100), 0);
        _reflectFee(rFee, tFee);
    }

    function _transferStandard(address sender, address recipient, uint256 rAmount, uint256 tTransferAmount, uint256 rTransferAmount) private {
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

        if(automatedReflectionsEnabled)
            try reflectionContract.logTransactionEvent(sender, rAmount, recipient, rTransferAmount){} catch {}
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function burn(uint256 amount) public {
        if(amount == 0)
            return;
        uint256 currentRate = _getRate();
        uint256 rAmount = amount.mul(currentRate);
        _rOwned[_msgSender()] = _rOwned[_msgSender()].sub(rAmount);
        if(automatedReflectionsEnabled)
            try reflectionContract.logTransactionEvent(_msgSender(), amount, address(0), 0) {} catch {}
        emit Burn(address(0), amount);
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

//        uint8 level = FeeLibrary.FeeLevels(_level - 1);
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

    function swapAndLiquify(uint256 contractTokenBalance) internal {
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
        swapTokensForEth(uniswapV2Router, address(this), half); // <- this breaks the ETH ->  swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        _approve(address(this), address(uniswapV2Router), otherHalf);
        addLiquidity(uniswapV2Router, address(this), otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapEthBasedFees(uint256 reflections, uint256 buyback) private returns(uint256 ethForReflections){
        uint256 initialBalance = address(this).balance;
        _approve(address(this), address(uniswapV2Router), reflections.add(buyback));
        // swap tokens for ETH
        swapTokensForEth(uniswapV2Router, address(this), reflections.add(buyback)); // <- this breaks the ETH ->  swap when swap+liquify is triggered

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
//        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
    }

    function updateLPPair(address newAddress) public onlyOwner {
        require(newAddress != address(uniswapV2Pair), "This pair is already in use");
        uniswapV2Pair = address(newAddress);
    }

    function buyBackTokens(uint256 amount) internal {
        if (amount > minBuyBack && amount < address(this).balance) {
            if(amount > maxBuyBack)
                amount = maxBuyBack;
            swapETHForTokens(uniswapV2Router, amount, buybackSinkAddress);
        }
        emit BuyBackTriggered(amount);
    }

    function setBuyBackEnabled(bool _enabled) public onlyOwner {
        buyBackEnabled = _enabled;
    }

    function setBuyBackRange(uint256 _minBuyBackEther, uint256 _maxBuyBackEther) public onlyOwner {
//        emit BuyBackRangeUpdated(minBuyBack, _minBuyBackEther, maxBuyBack, _maxBuyBackEther);
        minBuyBack = _minBuyBackEther * 1 ether;
        maxBuyBack = _maxBuyBackEther * 1 ether;
    }

    function updateBuybackSink(address _sinkAddress) public onlyOwner {
        buybackSinkAddress = _sinkAddress;
    }

    function init(address trueOwner) public onlyOwner{
        require(runOnce == 1, "This function can only ever be called once");
//        FeeLevels = FeeLibrary.FeeLevels;
//        FeeLevels = FeeLevel({1, 2, 3, 4, 5});

        initSellFees();
        openTrading();  // TODO Remove for mainnet
//        transferOwnership(trueOwner);
        runOnce = 0;
    }

    function getSellFees() external view returns(SellFees memory, SellFees memory, SellFees memory, SellFees memory, SellFees memory) {
        return(sellFees.level[1], sellFees.level[2], sellFees.level[3], sellFees.level[4], sellFees.level[5]);
    }
}