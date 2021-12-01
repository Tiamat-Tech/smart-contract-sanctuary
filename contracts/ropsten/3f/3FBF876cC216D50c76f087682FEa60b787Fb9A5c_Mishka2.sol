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

    uint256 private m_SellFee = 50; // 5% Sell Fee.
    uint256 private m_BuyFee = 50; // 5% Buy Fee.
    address private m_FeeWallet; // FeeWalletAddress.
    mapping(address => bool) private m_FeeIgnoreList;

    bool private m_TransferEnabled = false;
    mapping(address => bool) private m_Whitelist;

    address private m_UniswapV2Pair;
    IUniswapV2Router02 private m_UniswapV2Router;
    bool private m_SwapEnabled = false;

    receive() external payable {}

    modifier transferable(address _recipient) {
        if (!m_TransferEnabled) require(m_Whitelist[_recipient],"Not enabled transfer");
        _;
    }

    constructor() ERC20("Mishka Token2", "MISHKA2") {
        m_Whitelist[owner()] = true;
        m_Whitelist[address(this)] = true;
        m_FeeIgnoreList[address(this)] = true;
        _mint(address(this), TOTAL_SUPPLY);

    }

    // ##### Transfer Feature #####

    function setTransferEnabled(bool _enabled) external onlyOwner {
        m_TransferEnabled = _enabled;
    }

    function addWhitelist(address _address)
        external
        onlyOwner
    {
        m_Whitelist[_address] = true;
    }

    function removeWhitelist(address _address) external onlyOwner {
        m_Whitelist[_address] = false;
    }

    function isWhitelisted(address _address) external view returns (bool) {
        return m_Whitelist[_address];
    }

    function transfer(address _recipient, uint256 _amount)
        public
        override transferable(_recipient)
        returns (bool)
    {
        uint256 realAmount = _feeProcess(_msgSender(), _recipient, _amount);
        _transfer(_msgSender(), _recipient,realAmount);
        return true;
    }

    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override transferable(_recipient) returns (bool) {
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

    function setClaimRate(uint256 _rate) external onlyOwner {
        m_ClaimRate = _rate;
    }

    function getClaimRate() external view returns (uint256) {
        return m_ClaimRate;
    }

    function setClaimEnabled(bool _enabled) external onlyOwner {
        m_ClaimEnabled = _enabled;
    }

    function claimV2(uint256 _amount) external {
        require(m_ClaimEnabled, "Claim is not enabled");
        IERC20 mishkaV1 = IERC20(MISHKA1);
        require(
            _amount <= mishkaV1.balanceOf(_msgSender()),
            "Token balance is not enough"
        );

        uint256 claimAmount = _amount.mul(m_ClaimRate * (10**3));
        require(
            claimAmount <= balanceOf(address(this)),
            "Contract balance is not enough"
        );

        mishkaV1.transferFrom(_msgSender(), address(this), _amount);
        _transfer(address(this), _msgSender(), claimAmount);
    }

    // ###### Liquidity Feature ######

    function addLiquidity(uint256 _v2Amount, uint256 _ethAmount) external onlyOwner
    {
        require(!m_SwapEnabled, "Liquidity pool already created");
        require(_ethAmount <= address(this).balance,"Ethereum balance is not enough");

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        m_UniswapV2Router = _uniswapV2Router;

        _approve(address(this), address(m_UniswapV2Router), _v2Amount);

        m_UniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

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

    function setSellFee(uint256 _sellFee) external onlyOwner {
        m_SellFee = _sellFee;
    }

    function setBuyFee(uint256 _buyFee) external onlyOwner {
        m_BuyFee = _buyFee;
    }

    function setFeeWallet(address _feeWallet) external onlyOwner {
        m_FeeWallet = _feeWallet;
    }

    function addFeeIgnoreAddress(address _address) external onlyOwner {
        m_FeeIgnoreList[_address] = true;
    }

    function removeFeeIgnoreAddress(address _address) external onlyOwner{
        m_FeeIgnoreList[_address] = false;
    }

    function _isSale(address _sender, address _recipient) private view returns(bool) {
        return
            _sender == m_UniswapV2Pair &&
            _recipient != address(m_UniswapV2Router) && !m_FeeIgnoreList[_recipient];
    }

    function _isBuy(address _sender, address _recipient) private view returns(bool) {
        return
            _recipient == m_UniswapV2Pair &&
            _sender != address(m_UniswapV2Router) && !m_FeeIgnoreList[_sender];
    }

    function _feeProcess(address _sender, address _recipient, uint256 _amount) private returns(uint256) {
        uint256 fee;
        if(_isSale(_sender,_recipient)) fee = m_SellFee;
        else if(_isBuy(_sender,_recipient)) fee = m_BuyFee;
        else return _amount;

        uint256 feeAmount = _amount.mul(fee).div(1000);
        _transfer(_sender,m_FeeWallet,feeAmount);
        return _amount.sub(feeAmount);
    }

    // ##### Other Functions ######

    function withdraw(uint256 _amount) external onlyOwner
    {
        _transfer(address(this), owner(), _amount);
    }
}