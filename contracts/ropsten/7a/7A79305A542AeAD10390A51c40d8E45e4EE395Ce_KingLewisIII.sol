// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;
import "./utils/LPSwapSupport.sol";
import "./utils/ERC20SupplyRange.sol";

contract KingLewisIII is ERC20SupplyRange, LPSwapSupport {
    using SafeMath for uint256;
    using Address for address;
    using Address for address payable;

    struct Fees{
        uint256 liquidity;
        uint256 project;
        uint256 divisor;
    }

    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public _isExcludedFromFee;
    mapping (address => bool) private automatedMarketMakerPairs;

    string private _name = "King Lewis III";
    string private _symbol = "JCLIII";
    uint256 private _decimals = 18;

    bool tradingIsEnabled;

    Fees public fees;

    address public projectWallet;

    constructor (uint256 _supply, address routerAddress, address tokenOwner, address _projectWallet) ERC20SupplyRange() LPSwapSupport() {
        cappedSupply = _supply * 10 ** _decimals;
        circulatingSupply = cappedSupply.div(2);
        minSupply = cappedSupply.div(1000);

        canMint[_owner] = true;

        minTokenSpendAmount = cappedSupply.div(10 ** 8);

        projectWallet = _projectWallet;
        updateRouterAndPair(routerAddress);

        fees = Fees({
            liquidity: 3,
            project: 2,
            divisor: 100
        });

        _isExcludedFromFee[tokenOwner] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[projectWallet] = true;
        _owner = tokenOwner;
        balances[_owner] = circulatingSupply;

        emit Transfer(address(this), _owner, balances[_owner]);
    }

    fallback() external payable {}

    //to recieve BNB from pancakeswapV2Router when swaping
    receive() external payable {}

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return uint8(_decimals);
    }

    function totalSupply() public view override returns (uint256) {
        return circulatingSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
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
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "Transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "Decreased allowance below zero"));
        return true;
    }

    function setProjectWallet(address _projectWallet) public onlyOwner {
        projectWallet = _projectWallet;
    }

    function getOwner() external view returns(address){
        return owner();
    }

    function excludeFromFee(address account, bool shouldExclude) public onlyOwner {
        _isExcludedFromFee[account] = shouldExclude;
    }

    function _takeFees(address from, uint256 amount) private returns(uint256 transferAmount){

        uint256 liquidityFee = amount.mul(fees.liquidity).div(fees.divisor);
        uint256 projectFee = amount.mul(fees.project).div(fees.divisor);
        uint256 totalFees = projectFee.add(liquidityFee);

        balances[address(this)] = balances[address(this)].add(liquidityFee);
        balances[projectWallet] = balances[projectWallet].add(projectFee);

        emit Transfer(from, address(this), totalFees);
        emit Transfer(address(this), projectWallet, projectFee);
        transferAmount = amount.sub(totalFees);
    }

    function updateFees(uint256 liquidityFee, uint256 projectFee, uint256 feeDivisor) external onlyOwner {
        fees = Fees({
            liquidity: liquidityFee,
            project: projectFee,
            divisor: feeDivisor
        });
    }

    function _approve(address owner, address spender, uint256 amount) internal override {
        require(owner != address(0) && spender != address(0), "BEP20: Approve involves the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0) && to != address(0), "BEP20: Transfer involves the zero address");
        if(amount == 0){
            _transferStandard(from, to, 0, 0);
        }
        uint256 transferAmount = amount;

        if(from != owner() && to != owner() && !_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            if(automatedMarketMakerPairs[to] || automatedMarketMakerPairs[to]){
                require(tradingIsEnabled, "Trading is not enabled");
            }
            if(!inSwap && from != uniswapV2Pair && from != address(uniswapV2Router) && tradingIsEnabled) {
                selectSwapEvent();
            }
            transferAmount = _takeFees(from, amount);

        }
        _transferStandard(from, to, amount, transferAmount);
    }

    function selectSwapEvent() private lockTheSwap {
        if(!swapsEnabled) {return;}

        if(balanceOf(address(this)) >= minTokenSpendAmount){
            swapAndLiquify(balanceOf(address(this)));
        }
    }

    function _transferStandard(address sender, address recipient, uint256 amount, uint256 transferAmount) private {
        balances[sender] = balances[sender].sub(amount);
        balances[recipient] = balances[recipient].add(transferAmount);
        emit Transfer(sender, recipient, transferAmount);
    }

    function openTrading() external onlyOwner {
        require(!tradingIsEnabled, "Trading already open");
        tradingIsEnabled = true;
        swapsEnabled = true;
    }
}