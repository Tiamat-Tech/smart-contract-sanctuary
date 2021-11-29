pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract Mishka2 is Context, ERC20, Ownable {
    using SafeMath for uint256;

    // ##### Constant Value ######

    uint256 private constant TOTAL_SUPPLY = 1000000000 * 10**18;
    address private constant MISHKA1 =
        0x9BCA68f45feF973A3c5bd0ce3C270783F81D9D49;

    // ##### Tokenomic Private Value ####
    uint256 private m_ClaimRate = (1100 * 10**9) / (10**6); // 1,100 / 1,000,000 of V1 amount;

    uint256 private m_TxLimit = 5000000 * 10**18; // 0.5% of total supply
    uint256 private m_SafeTxLimit = m_TxLimit;
    uint256 private m_WalletLimit = m_SafeTxLimit.mul(4);

    uint256 private m_Market = 800; // 8% Marketing & Dev
    uint256 private m_Liquidity = 200; // 2% Liquidity
    address payable private m_MarketAddress;
    address payable private m_LiquidityAddress;

    uint256 private _numOfTokensForDisperse = 5000 * 10**18; // Exchange to Eth Limit - 5 Mil

    address private m_UniswapV2Pair;

    bool private m_TradingOpened = false;
    bool private m_PublicTradingOpened = false;
    bool private m_IsSwap = false;
    bool private m_SwapEnabled = false;

    mapping(address => bool) private m_Whitelist;
    mapping(address => bool) private m_Forgiven;
    mapping(address => bool) private m_Exchange;
    mapping(address => bool) private m_ExcludedAddresses;

    IUniswapV2Router02 private m_UniswapV2Router;

    event MaxOutTxLimit(uint256 MaxTransaction);

    modifier lockTheSwap() {
        m_IsSwap = true;
        _;
        m_IsSwap = false;
    }

    constructor() ERC20("Mishka Token2", "MISHKA2") {
        m_ExcludedAddresses[owner()] = true;
        m_ExcludedAddresses[address(this)] = true;
        _mint(address(this), TOTAL_SUPPLY);
    }

    // #####################
    // ##### OVERRIDES #####
    // #####################

    function transfer(address _recipient, uint256 _amount)
        public
        override
        returns (bool)
    {
        _mtransfer(_msgSender(), _recipient, _amount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mtransfer(_sender, _recipient, _amount);
        _approve(
            _sender,
            _msgSender(),
            allowance(_sender, _msgSender()).sub(
                _amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    // ####################
    // ##### PRIVATES #####
    // ####################

    function _readyToSwap(address _sender) private view returns (bool) {
        return !m_IsSwap && _sender != m_UniswapV2Pair && m_SwapEnabled;
    }

    function _trader(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return _sender != owner() && _recipient != owner() && m_TradingOpened;
    }

    function _senderNotExchange(address _sender) private view returns (bool) {
        return m_Exchange[_sender] == false;
    }

    function _txSale(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return
            _sender == m_UniswapV2Pair &&
            _recipient != address(m_UniswapV2Router) &&
            !m_ExcludedAddresses[_recipient];
    }

    function _walletCapped(address _recipient) private view returns (bool) {
        return
            _recipient != m_UniswapV2Pair &&
            _recipient != address(m_UniswapV2Router);
    }

    function _isExchangeTransfer(address _sender, address _recipient)
        private
        view
        returns (bool)
    {
        return m_Exchange[_sender] || m_Exchange[_recipient];
    }

    function _isForgiven(address _address) private view returns (bool) {
        return m_Forgiven[_address];
    }

    function _mtransfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        require(_sender != address(0), "ERC20: transfer from the zero address");
        require(
            _recipient != address(0),
            "ERC20: transfer to the zero address"
        );
        require(_amount > 0, "Transfer amount must be greater than zero");

        if (!m_PublicTradingOpened) require(m_Whitelist[_recipient]);

        if (_walletCapped(_recipient)) {
            uint256 _newBalance = balanceOf(_recipient).add(_amount);
            require(_newBalance < m_WalletLimit); // Check balance of recipient and if < max amount, fails
        }

        if (_trader(_sender, _recipient)) {
            if (_txSale(_sender, _recipient)) {
                require(_amount <= m_TxLimit);
                if (_isExchangeTransfer(_sender, _recipient)) _payToll(_sender);
            }
        }

        _handleBalances(_sender, _recipient, _amount); // Move coins
    }

    function _handleBalances(
        address _sender,
        address _recipient,
        uint256 _amount
    ) private {
        if (_isExchangeTransfer(_sender, _recipient)) {
            uint256 _marketBasisPoints = _getMarketBasisPoints(
                _sender,
                _recipient
            );
            uint256 _marketAmount = _amount.mul(_marketBasisPoints).div(10000);
            uint256 _newAmount = _amount.sub(_marketAmount);

            uint256 _liquidityBasisPoints = _getLiquidityBasisPoints(
                _sender,
                _recipient
            );
            uint256 _liquidityAmount = _amount.mul(_liquidityBasisPoints).div(
                10000
            );
            _newAmount = _newAmount.sub(_liquidityAmount);

            _burn(_sender, _amount);
            _mint(_recipient, _newAmount);
            _mint(address(this), _marketAmount.add(_liquidityAmount)); // Add toll + charity amount to total supply

            emit Transfer(_sender, _recipient, _newAmount);
        } else {
            _burn(_sender, _amount);
            _mint(_recipient, _amount);
            emit Transfer(_sender, _recipient, _amount);
        }
    }

    function _getMarketBasisPoints(address _sender, address _recipient)
        private
        view
        returns (uint256)
    {
        bool _take = !(m_ExcludedAddresses[_sender] ||
            m_ExcludedAddresses[_recipient]);
        if (!_take) return 0;
        return m_Market;
    }

    function _getLiquidityBasisPoints(address _sender, address _recipient)
        private
        view
        returns (uint256)
    {
        bool _take = !(m_ExcludedAddresses[_sender] ||
            m_ExcludedAddresses[_recipient]);
        if (!_take) return 0;
        return m_Liquidity;
    }

    function _payToll(address _sender) private {
        uint256 _tokenBalance = balanceOf(address(this));

        bool overMinTokenBalanceForDisperseEth = _tokenBalance >=
            _numOfTokensForDisperse;
        if (_readyToSwap(_sender) && overMinTokenBalanceForDisperseEth) {
            _swapTokensForETH(_tokenBalance);
            _disperseEth();
        }
    }

    function _swapTokensForETH(uint256 _amount) private lockTheSwap {
        address[] memory _path = new address[](2);
        _path[0] = address(this);
        _path[1] = m_UniswapV2Router.WETH();
        _approve(address(this), address(m_UniswapV2Router), _amount);
        m_UniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            _amount,
            0,
            _path,
            address(this),
            block.timestamp
        );
    }

    function _disperseEth() private {
        uint256 _ethBalance = address(this).balance;
        uint256 _total = m_Liquidity.add(m_Market);
        uint256 _liquidity = m_Liquidity.mul(_ethBalance).div(_total);
        m_LiquidityAddress.transfer(_liquidity);
        m_MarketAddress.transfer(_ethBalance.sub(_liquidity));
    }

    // ####################
    // ##### EXTERNAL #####
    // ####################

    function isWhitelisted(address _address) external view returns (bool) {
        return m_Whitelist[_address];
    }

    function isForgiven(address _address) external view returns (bool) {
        return m_Forgiven[_address];
    }

    function isExchangeAddress(address _address) external view returns (bool) {
        return m_Exchange[_address];
    }

    function claimV2(uint256 _amount) external {
        IERC20 mishkaV1 = IERC20(MISHKA1);
        require(
            _amount < mishkaV1.balanceOf(_msgSender()),
            "Token balance is not enough"
        );

        uint256 claimAmount = _amount.mul(m_ClaimRate);
        require(
            balanceOf(address(this)) < claimAmount,
            "Contract balance is not enough"
        );

        mishkaV1.transferFrom(_msgSender(), address(this), _amount);
        _transfer(address(this), _msgSender(), claimAmount);
    }

    // ######################
    // ##### ONLY OWNER #####
    // ######################

    function addLiquidity() external onlyOwner {
        require(!m_TradingOpened, "trading is already open");
        m_Whitelist[_msgSender()] = true;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        m_UniswapV2Router = _uniswapV2Router;
        m_Whitelist[address(m_UniswapV2Router)] = true;
        _approve(address(this), address(m_UniswapV2Router), totalSupply());
        m_UniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        m_Whitelist[m_UniswapV2Pair] = true;
        m_Exchange[m_UniswapV2Pair] = true;
        m_UniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );
        m_SwapEnabled = true;
        m_TradingOpened = true;
        IERC20(m_UniswapV2Pair).approve(
            address(m_UniswapV2Router),
            type(uint256).max
        );
    }

    function setTxLimit(uint256 txLimit) external onlyOwner {
        uint256 txLimitWei = txLimit * 10**18; // Set limit with token instead of wei
        require(txLimitWei > totalSupply().div(1000)); // Minimum TxLimit is 0.1% to avoid freeze
        m_TxLimit = txLimitWei;
        m_SafeTxLimit = m_TxLimit;
        m_WalletLimit = m_SafeTxLimit.mul(4);
    }

    function setMarketBasisPoints(uint256 toll) external onlyOwner {
        require(toll <= 1000); // Max Toll can be set to 5%
        m_Market = toll;
    }

    function setLiquidityBasisPoints(uint256 charity) external onlyOwner {
        require(charity <= 1000); // Max Charity can be set to 5%
        m_Liquidity = charity;
    }

    function setNumOfTokensForDisperse(uint256 tokens) external onlyOwner {
        uint256 tokensToDisperseWei = tokens * 10**18; // Set limit with token instead of wei
        _numOfTokensForDisperse = tokensToDisperseWei;
    }

    function setTxLimitMax() external onlyOwner {
        // MaxTx set to MaxWalletLimit
        m_TxLimit = m_WalletLimit;
        m_SafeTxLimit = m_WalletLimit;
        emit MaxOutTxLimit(m_TxLimit);
    }

    function contractBalance() external view onlyOwner returns (uint256) {
        // Used to verify initial balance for addLiquidity
        return address(this).balance;
    }

    function setMarketAddress(address payable _marketAddress)
        external
        onlyOwner
    {
        m_MarketAddress = _marketAddress;
        m_ExcludedAddresses[_marketAddress] = true;
    }

    function setLiquidityAddress(address payable _liquidityAddress)
        external
        onlyOwner
    {
        m_LiquidityAddress = _liquidityAddress;
        m_ExcludedAddresses[_liquidityAddress] = true;
    }

    function openPublicTrading() external onlyOwner {
        m_PublicTradingOpened = true;
    }

    function isPublicTradingOpen() external view onlyOwner returns (bool) {
        return m_PublicTradingOpened;
    }

    function addWhitelist(address _address) public onlyOwner {
        m_Whitelist[_address] = true;
    }

    function addWhitelistMultiple(address[] memory _addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            addWhitelist(_addresses[i]);
        }
    }

    function removeWhitelist(address _address) external onlyOwner {
        m_Whitelist[_address] = false;
    }

    // This exists in the event an address is falsely banned
    function forgiveAddress(address _address) external onlyOwner {
        m_Forgiven[_address] = true;
    }

    function rmForgivenAddress(address _address) external onlyOwner {
        m_Forgiven[_address] = false;
    }

    function addExchangeAddress(address _address) external onlyOwner {
        m_Exchange[_address] = true;
    }

    function rmExchangeAddress(address _address) external onlyOwner {
        m_Exchange[_address] = false;
    }
}