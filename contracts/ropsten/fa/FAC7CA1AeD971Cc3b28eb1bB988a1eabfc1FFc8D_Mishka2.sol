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
    uint256 private m_ClaimRate = 1100; // unit 1 / 10**6 ;
    bool private m_ClaimEnabled = true;
    address private m_ClaimWallet;

    uint256 private m_SellFee = 50; // 5% Sell Fee.
    uint256 private m_BuyFee = 50; // 5% Buy Fee.
    address payable private m_FeeWallet; // FeeWalletAddress.
    bool private m_IsSwap = false;
    mapping(address => bool) private m_FeeIgnoreList;

    mapping(address => bool) private m_WhiteList;
    mapping(address => bool) private m_BlackList;
    bool private m_PublicTradingOpened = false;
    uint256 private m_CoolDownSeconds = 0;
    mapping(address => uint256) private m_Cooldown;
    uint256 private m_TxLimit  = 5000000 * 10**18; // 0.5% of total supply
    uint256 private m_MaxWalletSize = 40000000 * 10**18; // 4% of total supply

    uint256 private _numOfTokensForDisperse = 5000 * 10**18; // Exchange to Eth Limit - 5 Mil

    address private m_UniswapV2Pair;
    IUniswapV2Router02 private m_UniswapV2Router;
    bool private m_SwapEnabled = false;

    receive() external payable {}

    modifier lockTheSwap {
        m_IsSwap = true;
        _;
        m_IsSwap = false;
    }

    modifier transferable(address _sender, address _recipient, uint256 _amount) {
        if(!m_WhiteList[_recipient])
        {
            require(m_PublicTradingOpened,"Not enabled transfer.");
            require(!m_BlackList[_recipient],"You are in block list.");
            if (m_CoolDownSeconds >  0) {
                require(m_Cooldown[_sender] < block.timestamp,"Need to wait for cooldown");
                m_Cooldown[_sender] = block.timestamp + ( m_CoolDownSeconds * (1 seconds));
            }

            require(_amount <= m_TxLimit, "Amount is bigg too.");
        }
        _;
        if( _recipient != address(this) &&
            _recipient != m_FeeWallet &&
            _recipient != m_ClaimWallet )
            require(ERC20.balanceOf(_recipient) <= m_MaxWalletSize, "The balance is big too");
    }

    constructor() ERC20("Mishka Token2", "MISHKA2") {
        m_WhiteList[owner()] = true;
        m_WhiteList[address(this)] = true;
        m_FeeIgnoreList[address(this)] = true;
        m_ClaimWallet = address(this);
        m_FeeWallet = payable(address(this));
        _mint(address(this), TOTAL_SUPPLY);
    }

    // function balanceOf(address account) public view override returns (uint256) {
    //     uint256 balance = ERC20.balanceOf(account);
    //     balance = balance - (balance % (10**18));
    //     return balance;
    // }



    // ##### Transfer Feature #####

    function setPublicTradingOpened(bool _enabled) external onlyOwner 
    {
        m_PublicTradingOpened = _enabled;
    }
    function isPublicTradingOpen() external onlyOwner() view returns (bool) {
        return m_PublicTradingOpened;
    }

    function addWhiteList(address _address) public onlyOwner() {
        m_WhiteList[_address] = true;
    }
    
    function addWhiteListMultiple(address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            addWhiteList(_addresses[i]);
        }
    }

    function removeWhiteList(address _address) external onlyOwner() {
        m_WhiteList[_address] = false;
    }
    function isWhiteListed(address _address) external view returns (bool) 
    {
        return m_WhiteList[_address];
    }

    function addBlackList(address _address) public onlyOwner() {
        m_BlackList[_address] = true;
    }
    
    function addBlackListMultiple(address[] memory _addresses) public onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            addBlackList(_addresses[i]);
        }
    }

    function removeBlackList(address _address) external onlyOwner() {
        m_BlackList[_address] = false;
    }
    function isBlackListed(address _address) external view returns (bool) 
    {
        return m_BlackList[_address];
    }

    function setCoolDownSeconds(uint256 _coolDownSeconds) external onlyOwner() {
        m_CoolDownSeconds = _coolDownSeconds;
    }
    
    function getCoolDownSeconds() public view returns (uint256) {
        return m_CoolDownSeconds;
    }

    function setTxLimit(uint256 _txLimit) external onlyOwner()
    {
        m_TxLimit = _txLimit;
    }

    function setMaxWalletSize(uint256 _maxWalletSize) external onlyOwner()
    {
        m_TxLimit = _maxWalletSize;
    }

    function transfer(address _recipient, uint256 _amount) public
        override transferable(_msgSender(),_recipient,_amount)
        returns (bool)
    {
        uint256 realAmount = _feeProcess(_msgSender(), _recipient, _amount);
        _transfer(_msgSender(), _recipient,realAmount);
        return true;
    }

    function transferFrom(address _sender,address _recipient,uint256 _amount) public 
        override transferable(_sender,_recipient,_amount) returns (bool) 
    {
        uint256 realAmount = _feeProcess(_sender, _recipient, _amount);
        _transfer(_sender, _recipient,realAmount);
        
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

    // ###### Claim Feature ######

    function setClaimRate(uint256 _rate) external onlyOwner()
    {
        m_ClaimRate = _rate;
    }

    function getClaimRate() external view returns (uint256) 
    {
        return m_ClaimRate;
    }

    function setClaimEnabled(bool _enabled) external onlyOwner()
    {
        m_ClaimEnabled = _enabled;
    }

    function setClaimWallet(address _claimWallet) external onlyOwner()
    {
        m_ClaimWallet = _claimWallet;
        m_FeeIgnoreList[_claimWallet] = true;
        m_WhiteList[_claimWallet] = true;
    }

    function getClaimWallet() external view onlyOwner() returns(address)
    {
        return m_ClaimWallet;
    }

    function claimV2(uint256 _amount) external 
    {
        require(m_ClaimEnabled, "Claim is not enabled");
        IERC20 mishkaV1 = IERC20(MISHKA1);
        require(
            _amount <= mishkaV1.balanceOf(_msgSender()),
            "Token balance is not enough"
        );

        uint256 claimAmount = _amount.mul(m_ClaimRate * (10**3));
        require(
            claimAmount <= ERC20.balanceOf(m_ClaimWallet),
            "Claim Wallet balance is not enough"
        );

        mishkaV1.transferFrom(_msgSender(), address(this), _amount);
        _transfer(m_ClaimWallet, _msgSender(), claimAmount);
    }

    // ###### Liquidity Feature ######

    function addLiquidity(uint256 _v2Amount, uint256 _ethAmount) external onlyOwner()
    {
        require(!m_SwapEnabled, "Liquidity pool already created");
        require(_ethAmount <= address(this).balance,"Ethereum balance is not enough");

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        m_UniswapV2Router = _uniswapV2Router;

        m_WhiteList[address(m_UniswapV2Router)] = true;
        _approve(address(this), address(m_UniswapV2Router), _v2Amount);

        m_UniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        m_WhiteList[m_UniswapV2Pair] = true;

        m_UniswapV2Router.addLiquidityETH{value: _ethAmount}(
            address(this),
            _v2Amount,
            0,
            0,
            owner(),
            block.timestamp
        );
        m_SwapEnabled = true;
        IERC20(m_UniswapV2Pair).approve(
            address(m_UniswapV2Router),
            type(uint256).max
        );
    }

    // ##### Fee Feature ######

    function setSellFee(uint256 _sellFee) external onlyOwner()
    {
        m_SellFee = _sellFee;
    }

    function setBuyFee(uint256 _buyFee) external onlyOwner() 
    {
        m_BuyFee = _buyFee;
    }

    function setFeeWallet(address payable _feeWallet) external onlyOwner() 
    {
        m_FeeWallet = _feeWallet;
    }

    function addFeeIgnoreAddress(address _address) external onlyOwner() 
    {
        m_FeeIgnoreList[_address] = true;
    }

    function removeFeeIgnoreAddress(address _address) external onlyOwner()
    {
        m_FeeIgnoreList[_address] = false;
    }

    function _isBuy(address _sender, address _recipient) private view returns(bool) {
        return
            _sender == m_UniswapV2Pair &&
            _recipient != address(m_UniswapV2Router) && !m_FeeIgnoreList[_recipient];
    }

    function _isSale(address _sender, address _recipient) private view returns(bool) {
        return
            _recipient == m_UniswapV2Pair &&
            _sender != address(m_UniswapV2Router) && !m_FeeIgnoreList[_sender];
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

    function _readyToSwap() private view returns(bool) {
        return !m_IsSwap && m_SwapEnabled;
    }

    function _payToll() private {
        uint256 _tokenBalance = balanceOf(address(this));
        
        bool overMinTokenBalanceForDisperseEth = _tokenBalance >= _numOfTokensForDisperse;
        if (_readyToSwap() && overMinTokenBalanceForDisperseEth) {
            _swapTokensForETH(_tokenBalance);
            // if(m_FeeWallet != payable(address(this)))
            //     m_FeeWallet.transfer(address(this).balance);
        }
    }

    function _feeProcess(address _sender, address _recipient, uint256 _amount) private returns(uint256) {
        uint256 fee;
        bool isSale = _isSale(_sender,_recipient);
        bool isBuy = _isBuy(_sender,_recipient);
        if(isSale) fee = m_SellFee;
        else if(isBuy) fee = m_BuyFee;
        else return _amount;

        if(fee == 0) return _amount;

        uint256 feeAmount = _amount.mul(fee).div(1000);
        _transfer(_sender,address(this),feeAmount);

        if(isSale) _payToll();
        return _amount.sub(feeAmount);
    }

    // ##### Other Functions ######

    function withdraw(uint256 _amount) external onlyOwner()
    {
        _transfer(address(this), owner(), _amount);
    }

    function withdrawV1(uint256 _amount) external onlyOwner()
    {
        IERC20 mishkaV1 = IERC20(MISHKA1);
        mishkaV1.transfer(owner(), _amount);
    }

    function withdrawFee() external onlyOwner()
    {
        if(m_FeeWallet != payable(address(this)))
            m_FeeWallet.transfer(address(this).balance);
    }

    function isSetFeeWallet() external view onlyOwner() returns(bool)
    {
        return m_FeeWallet != payable(address(this));
    }

    function getFeeWalletBalanace() external view onlyOwner() returns(uint256)
    {
        return address(this).balance;
    }
}