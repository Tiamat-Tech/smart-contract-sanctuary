////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//////////////////////   ///////////////////////////////////////////////////////
/////////////////////       ////////////////////////////////////////////////////
//////////////////////        //////////////////////       /////////////////////
///////////////////////        ///////////////////         /////////////////////
/////////////////////////       /////////////////         //////////////////////
///////////////////////////      ///////////////       .////////////////////////
////////////////////////////      /////////////       //////////////////////////
/////////////////////////////     /////////////     ////////////////////////////
//////////////////////////////     ///////////     /////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////                   //////////////////////////////
///////////////////////////////                   //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
///////////////////////////////    ///////////    //////////////////////////////
////////////////////////////////, /////////////, ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

/**
    https://hare.travel
    @author: Coeus
 */

// contracts/Hare.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "./interfaces/IBEP20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract Hare is ContextUpgradeable, IBEP20, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    string private constant _name = "Hare";
    string private constant _symbol = "HARE";
    uint8 private constant _decimals = 9;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromLimits;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant TOTAL_COIN = 1000000000000;
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    uint256 public _advisoryFee;
    uint256 public _developmentFee;
    uint256 public _reflectionFee;
    uint256 public _liquidityFee;
    uint256 public _marketingFee;
    uint256 private _previousReflectionFee;
    uint256 public _companyTotalFees;
    uint256 private _previousTotalCompanyFees;
    uint256 public maxWalletAmount;

    mapping(address => bool) private bots;
    address payable public _advisoryWalletAddress;
    address payable public _marketingWalletAddress;
    address payable public _developmentWalletAddress;
    address payable public _liquidityWalletAddress;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    bool public isTradingEnabled;
    bool private liquidityAdded;
    bool private inSwap;
    bool private isSwapEnabled;
    uint256 public _maxTxAmount;

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromLimits(address indexed account, bool isExcluded);
    event FeesDisabled(bool enabled);
    event FeesEnabled(bool enabled);
    event LiquiditySet(bool completed);
    event LiquidityPercentSet(uint256 oldFee, uint256 newFee);
    event MaxTxAmountPerMilleUpdated(uint256 maxTxAmount);
    event MaxTxAmountUpdated(uint256 maxTxAmount);
    event ManualSend(uint256 contractETHBalance);
    event ManualSwap(uint256 contractBalance);
    event OpenLiquidity(bool enabled);
    event OpenTrading(bool enabled);
    event PairAddressSet(bool completed);
    event RouterAddressUpdated(address newRouter);
    event SweptBNB(bool completed);
    event SweptTokens(address to, uint256 amount);
    event UpdatedAdvisoryWallet(
        address indexed oldAddress,
        address indexed newAddress
    );
    event UpdatedDevelopmentWallet(
        address indexed oldAddress,
        address indexed newAddress
    );
    event UpdatedLiquidityWallet(
        address indexed oldAddress,
        address indexed newAddress
    );
    event UpdatedMarketingWallet(
        address indexed oldAddress,
        address indexed newAddress
    );

    event AdvisoryTaxPercentSet(uint256 oldFee, uint256 newFee);
    event DevelopmentTaxPercentSet(uint256 oldFee, uint256 newFee);
    event MarketingTaxPercentSet(uint256 oldFee, uint256 newFee);
    event ReflectionTaxPercentSet(uint256 oldFee, uint256 newFee);

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    function initialize(
        address payable advAddr,
        address payable devAddr,
        address payable mktgAddr,
        address payable liqAddr
    ) public initializer {
        __Ownable_init();

        _tTotal = TOTAL_COIN * 10**uint8(_decimals);
        _rTotal = (MAX - (MAX % _tTotal));
        _tFeeTotal;
        _advisoryFee = 1;
        _developmentFee = 2;
        _reflectionFee = 2;
        _liquidityFee = 3;
        _marketingFee = 2;
        _previousReflectionFee = _reflectionFee;
        _companyTotalFees =
            _advisoryFee +
            _developmentFee +
            _liquidityFee +
            _marketingFee;
        _previousTotalCompanyFees = _companyTotalFees;
        maxWalletAmount = 10000000000 * 10**uint8(_decimals);

        _advisoryWalletAddress = payable(advAddr);
        _developmentWalletAddress = payable(devAddr);
        _marketingWalletAddress = payable(mktgAddr);
        _liquidityWalletAddress = payable(liqAddr);

        isTradingEnabled = false;
        liquidityAdded = false;
        inSwap = false;
        isSwapEnabled = false;
        _maxTxAmount = (totalSupply() * 2) / 1000;
        _rOwned[_msgSender()] = _rTotal;

        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(_advisoryWalletAddress, true);
        excludeFromFees(_marketingWalletAddress, true);
        excludeFromFees(_developmentWalletAddress, true);
        excludeFromFees(_liquidityWalletAddress, true);

        excludeFromLimits(owner(), true);
        excludeFromLimits(address(this), true);
        excludeFromLimits(_advisoryWalletAddress, true);
        excludeFromLimits(_marketingWalletAddress, true);
        excludeFromLimits(_developmentWalletAddress, true);
        excludeFromLimits(_liquidityWalletAddress, true);

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() external pure returns (string memory) {
        return _name;
    }

    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function manualSend() external onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);

        emit ManualSend(contractETHBalance);
    }

    function manualSwap() external onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);

        emit ManualSwap(contractBalance);
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: Approve from the zero address");
        require(spender != address(0), "ERC20: Approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            if (!_isExcludedFromLimits[from] || !_isExcludedFromLimits[to]) {
                if (from == uniswapV2Pair || to == uniswapV2Pair) {
                    require(
                        amount <= _maxTxAmount,
                        "You are exceeding max transaction amount"
                    );
                }

                if (to != uniswapV2Pair) {
                    require(
                        balanceOf(to) + amount <= maxWalletAmount,
                        "Maximum wallet size limit"
                    );
                }
            }

            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                isSwapEnabled
            ) {
                require(isTradingEnabled, "Trading is not active.");
            }

            uint256 contractTokenBalance = balanceOf(address(this));

            if (!inSwap && from != uniswapV2Pair && isSwapEnabled) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        bool takeFee = true;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        _tokenTransfer(from, to, amount, takeFee);
        restoreAllFee;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function setMaxTxAmountPerMille(uint8 newMaxTxAmountPerMille)
        external
        onlyOwner
    {
        require(
            newMaxTxAmountPerMille >= 1 && newMaxTxAmountPerMille <= 1000,
            "Max Tc must be between 0.1% (1) and 100% (1000)"
        );
        uint256 newMaxTxAmount = (totalSupply() * newMaxTxAmountPerMille) /
            1000;
        _maxTxAmount = newMaxTxAmount;

        emit MaxTxAmountPerMilleUpdated(_maxTxAmount);
    }

    function setMaxWalletPerMille(uint8 maxWalletPerMille) external onlyOwner {
        require(
            maxWalletPerMille >= 1 && maxWalletPerMille <= 1000,
            "Max wallet percentage must be between 0.1% (1) and 100% (1000)"
        );
        uint256 newMaxWalletAmount = (totalSupply() * maxWalletPerMille) / 1000;
        maxWalletAmount = newMaxWalletAmount;
    }

    function excludeFromLimits(address walletAddress, bool excluded)
        public
        onlyOwner
    {
        _isExcludedFromLimits[walletAddress] = excluded;

        emit ExcludeFromLimits(walletAddress, excluded);
    }

    function excludeFromFees(address walletAddress, bool excluded)
        public
        onlyOwner
    {
        _isExcludedFromFees[walletAddress] = excluded;

        emit ExcludeFromFees(walletAddress, excluded);
    }

    function tokenFromReflection(uint256 rAmount)
        private
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

    function sendETHToFee(uint256 amount) private {
        _advisoryWalletAddress.transfer(
            amount.mul(_advisoryFee).div(_companyTotalFees)
        );
        _marketingWalletAddress.transfer(
            amount.mul(_marketingFee).div(_companyTotalFees)
        );
        _developmentWalletAddress.transfer(
            amount.mul(_developmentFee).div(_companyTotalFees)
        );
        _liquidityWalletAddress.transfer(
            amount.mul(_liquidityFee).div(_companyTotalFees)
        );
    }

    function openLiquidity(bool _enabled) external onlyOwner {
        isSwapEnabled = _enabled;
        liquidityAdded = _enabled;

        emit OpenLiquidity(_enabled);
    }

    function openTrading(bool _enabled) external onlyOwner {
        require(liquidityAdded, "Liquidity not enabled.");
        isTradingEnabled = _enabled;

        emit OpenTrading(_enabled);
    }

    function addLiquidity() external onlyOwner {
        require(
            address(uniswapV2Router) != address(0),
            "UniswapV2Router not set."
        );
        require(address(uniswapV2Pair) != address(0), "UniswapV2Pair not set.");

        _approve(address(this), address(uniswapV2Router), _tTotal);

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );

        IBEP20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );

        emit LiquiditySet(true);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();
        _transferStandard(sender, recipient, amount);
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
            uint256 tTeam
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTeam(tTeam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeTeam(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    receive() external payable {}

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
        (uint256 tTransferAmount, uint256 tFee, uint256 tCompany) = _getTValues(
            tAmount,
            _reflectionFee,
            _companyTotalFees
        );
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tCompany,
            currentRate
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tCompany
        );
    }

    function _getTValues(
        uint256 tAmount,
        uint256 taxFee,
        uint256 companyFee
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tCompany = tAmount.mul(companyFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tCompany);
        return (tTransferAmount, tFee, tCompany);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tCompany,
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
        uint256 rCompany = tCompany.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rCompany);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function setPairAddress() public onlyOwner {
        require(
            address(uniswapV2Router) != address(0),
            "Must set uniswapV2Router first"
        );

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(
            address(this),
            uniswapV2Router.WETH()
        );

        if (uniswapV2Pair == address(0)) {
            uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
                .createPair(address(this), uniswapV2Router.WETH());
        }

        emit PairAddressSet(true);
    }

    function updateRouterAddress(address newRouter) external onlyOwner {
        require(address(newRouter) != address(0), "Address cannot be 0");
        require(
            newRouter != address(uniswapV2Router),
            "Router already has that address"
        );

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(newRouter);
        uniswapV2Router = _uniswapV2Router;

        emit RouterAddressUpdated(newRouter);
    }

    function updateAdvisoryWalletAddress(address payable advisoryWalletAddress)
        external
        onlyOwner
    {
        require(
            address(advisoryWalletAddress) != address(0),
            "Address cannot be 0"
        );

        address oldAddress = _advisoryWalletAddress;
        excludeFromFees(advisoryWalletAddress, true);
        excludeFromFees(_advisoryWalletAddress, false);
        excludeFromLimits(advisoryWalletAddress, true);
        excludeFromLimits(_advisoryWalletAddress, false);
        _advisoryWalletAddress = advisoryWalletAddress;

        emit UpdatedAdvisoryWallet(oldAddress, _advisoryWalletAddress);
    }

    function updateDevelopmentWalletAddress(
        address payable developmentWalletAddress
    ) external onlyOwner {
        require(
            address(developmentWalletAddress) != address(0),
            "Address cannot be 0"
        );

        address oldAddress = _developmentWalletAddress;
        excludeFromFees(developmentWalletAddress, true);
        excludeFromFees(_developmentWalletAddress, false);
        excludeFromLimits(developmentWalletAddress, true);
        excludeFromLimits(_developmentWalletAddress, false);
        _developmentWalletAddress = developmentWalletAddress;

        emit UpdatedDevelopmentWallet(oldAddress, _developmentWalletAddress);
    }

    function updateLiquidityWalletAddress(
        address payable liquidityWalletAddress
    ) external onlyOwner {
        require(
            address(liquidityWalletAddress) != address(0),
            "Address cannot be 0"
        );

        address oldAddress = _liquidityWalletAddress;
        excludeFromLimits(liquidityWalletAddress, true);
        excludeFromLimits(_liquidityWalletAddress, false);
        _liquidityWalletAddress = liquidityWalletAddress;

        emit UpdatedLiquidityWallet(oldAddress, _liquidityWalletAddress);
    }

    function updateMarketingWalletAddress(
        address payable marketingWalletAddress
    ) external onlyOwner {
        require(
            address(marketingWalletAddress) != address(0),
            "Address cannot be 0"
        );

        address oldAddress = _marketingWalletAddress;
        excludeFromFees(marketingWalletAddress, true);
        excludeFromFees(_marketingWalletAddress, false);
        excludeFromLimits(marketingWalletAddress, true);
        excludeFromLimits(_marketingWalletAddress, false);
        _marketingWalletAddress = marketingWalletAddress;

        emit UpdatedMarketingWallet(oldAddress, _marketingWalletAddress);
    }

    function setReflectionTaxPercent(uint256 newFee) external onlyOwner {
        uint256 oldFee = _reflectionFee;
        _reflectionFee = newFee;
        _previousReflectionFee = _reflectionFee;

        emit ReflectionTaxPercentSet(oldFee, _reflectionFee);
    }

    function setAdvisoryTaxPercent(uint256 newFee) external onlyOwner {
        uint256 oldFee = _advisoryFee;
        _advisoryFee = newFee;
        _companyTotalFees =
            _marketingFee +
            _developmentFee +
            _advisoryFee +
            _liquidityFee;
        _previousTotalCompanyFees = _companyTotalFees;

        emit AdvisoryTaxPercentSet(oldFee, _advisoryFee);
    }

    function setDevelopmentTaxPercent(uint256 newFee) external onlyOwner {
        uint256 oldFee = _developmentFee;
        _developmentFee = newFee;
        _companyTotalFees =
            _marketingFee +
            _developmentFee +
            _advisoryFee +
            _liquidityFee;
        _previousTotalCompanyFees = _companyTotalFees;

        emit DevelopmentTaxPercentSet(oldFee, _developmentFee);
    }

    function setMarketingTaxPercent(uint256 newFee) external onlyOwner {
        uint256 oldFee = _marketingFee;
        _marketingFee = newFee;
        _companyTotalFees =
            _marketingFee +
            _developmentFee +
            _advisoryFee +
            _liquidityFee;
        _previousTotalCompanyFees = _companyTotalFees;

        emit MarketingTaxPercentSet(oldFee, _marketingFee);
    }

    function setLiquidityTaxPercent(uint256 liquidityFee) external onlyOwner {
        uint256 oldFee = _liquidityFee;
        _liquidityFee = liquidityFee;
        _companyTotalFees =
            _marketingFee +
            _developmentFee +
            _advisoryFee +
            _liquidityFee;
        _previousTotalCompanyFees = _companyTotalFees;

        emit LiquidityPercentSet(oldFee, _liquidityFee);
    }

    function removeAllFee() private {
        if (_reflectionFee == 0 && _companyTotalFees == 0) return;

        _previousReflectionFee = _reflectionFee;
        _reflectionFee = 0;
        _previousTotalCompanyFees = _companyTotalFees;
        _companyTotalFees = 0;

        emit FeesDisabled(true);
    }

    function restoreAllFee() private {
        _reflectionFee = _previousReflectionFee;

        _companyTotalFees =
            _advisoryFee +
            _developmentFee +
            _liquidityFee +
            _marketingFee;

        _previousTotalCompanyFees = _companyTotalFees;

        emit FeesEnabled(true);
    }

    // Used to withdraw any BNB which is in the contract address by mistake
    function sweepBNB(uint256 amount) public onlyOwner {
        if (address(this).balance == 0) {
            revert("Contract has a zero balance.");
        } else {
            if (amount == 0) {
                payable(owner()).transfer(address(this).balance);
            } else {
                payable(owner()).transfer(amount);
            }

            emit SweptBNB(true);
        }
    }

    // Used to withdraw tokens transferred to this address by mistake
    function sweepTokens(address token, uint256 amount) public onlyOwner {
        require(amount > 0, "Invalid amount supplied.");
        IBEP20(address(token)).transfer(msg.sender, amount);

        emit SweptTokens(msg.sender, amount);
    }
}