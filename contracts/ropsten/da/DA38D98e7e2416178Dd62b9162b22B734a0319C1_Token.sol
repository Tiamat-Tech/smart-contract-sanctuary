// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract Token is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    struct UserDeposit {
        uint256 amount;
        uint256 time;
    }

    /**
     *
     * @dev User reflects the info of each user
     *
     *
     * @param {total_invested} how many tokens the user staked
     * @param {total_withdrawn} how many tokens withdrawn so far
     * @param {lastPayout} time at which last claim was done 
     * @param {deposits} info about each deposit made
     *
     */
    struct User {
        uint256 total_invested;
        uint256 total_withdrawn;
        uint256 lastPayout;
        UserDeposit[] deposits;
    }

    /**
     *
     * @dev Pool reflects the info of pool
     * 
     *
     *
     * @param {apy} Percentage of yield produced by the pool (with two extra zero)
     * if APY is 5%, give it as 500 for precision           
     * @param {totalDeposit} Total deposit in the pool
     * @param {minContrib} Minimum amount to be staked
     * @param {maxContrib} Maximum amount that can be staked
     *
     */

    struct Pool{
        uint16 apy;
        uint256 totalDeposit;
        uint256 minContrib;
        uint256 maxContrib;
    }

    IERC20 private token; //Token address

    mapping(address => User) public users;

    Pool public poolInfo;

    event Stake(address indexed addr, uint256 amount);
    event Claim(address indexed addr, uint256 amount);

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;

    address[] private _excluded;
    address private feeWallet1;
    address private feeWallet2;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1* 10**12 * 10**9;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = "Token";
    string private _symbol = "TKN";
    uint8 private _decimals = 9;
    
    uint256 public _taxFee = 1;
    uint256 private _previousTaxFee = _taxFee;

    uint256 public _adminFee = 1;
    uint256 private _previousAdminFee = _adminFee;
    
    uint256 public _maxTxAmount = 1 * 10**12 * 10**9;

    
    constructor (
        address teamWallet, address marketingWallet, address icoWallet,
        address _feeWallet1, address _feeWallet2,
        uint256 minContrib, uint256 maxContrib) {
        _rOwned[_msgSender()] = _rTotal;
        feeWallet1 = _feeWallet1;
        feeWallet2 = _feeWallet2;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[address(0x123)] = true; //Where token for staking will be stored
        
        init(address(this),5000,minContrib,maxContrib); //50% apy

        emit Transfer(address(0), _msgSender(), _tTotal);

        _transfer(owner(),teamWallet,2* 10**11 * 10**9);
        _transfer(owner(),marketingWallet,1* 10**11 * 10**9);
        _transfer(owner(),icoWallet,3* 10**11 * 10**9);
        _transfer(owner(),address(0x123),4* 10**11 * 10**9);

        _approve(address(0x123), address(this), MAX);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
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

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account) public onlyOwner() {
        // require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
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
    
    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    function setAdminFeePercent(uint256 adminFee) external onlyOwner() {
        _adminFee = adminFee;
    }
   
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }

    function setFeeWallet(address add1, address add2) external onlyOwner() {
        feeWallet1 = add1;
        feeWallet2 = add2;
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _takeAdmin(uint256 tAdmin) private {
        uint256 currentRate =  _getRate();
        uint256 rAdmin = tAdmin.mul(currentRate);

        _rOwned[feeWallet1] = _rOwned[feeWallet1].add(rAdmin.div(2));
        _tOwned[feeWallet1] = _tOwned[feeWallet1].add(tAdmin.div(2));

        _rOwned[feeWallet2] = _rOwned[feeWallet2].add(rAdmin.div(2));
        _tOwned[feeWallet2] = _tOwned[feeWallet2].add(tAdmin.div(2));
        
        emit Transfer(tx.origin, feeWallet1, tAdmin.div(2));
        emit Transfer(tx.origin, feeWallet2, tAdmin.div(2));
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tAdmin) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, tAdmin, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tAdmin);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tAdmin = calculateAdminFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tAdmin);
        return (tTransferAmount, tFee, tAdmin);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 tAdmin, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rAdmin = tAdmin.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rAdmin);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }

    function calculateAdminFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_adminFee).div(
            10**2
        );
    }
    
    function removeAllFee() private {
        if(_taxFee == 0 && _adminFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousAdminFee = _adminFee;
        
        _taxFee = 0;
        _adminFee = 0;
    }
    
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _adminFee = _previousAdminFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner()){
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee);
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee)
            removeAllFee();
        
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tAdmin) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeAdmin(tAdmin);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tAdmin) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _reflectFee(rFee, tFee);
        _takeAdmin(tAdmin);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tAdmin) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _reflectFee(rFee, tFee);
        _takeAdmin(tAdmin);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tAdmin) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _reflectFee(rFee, tFee);
        _takeAdmin(tAdmin);
        emit Transfer(sender, recipient, tTransferAmount);
    }

     function init(address _token, uint16 _apy, uint256 _minContrib, uint256 _maxContrib) internal{

        token = IERC20(_token);
        transferOwnership(tx.origin);

        poolInfo.apy = _apy;
        poolInfo.totalDeposit = 0;
        poolInfo.minContrib = _minContrib;
        poolInfo.maxContrib = _maxContrib;
    }

     /**
     *
     * @dev depsoit tokens to staking
     *
     * @param {_amount} Amount to be staked
     *
     * @return {bool} Status of stake
     *
     */
    function stake(uint256 _amount) external returns(bool) {
        require(token.allowance(msg.sender,address(this)) >= _amount,
        "Token : Set allowance first!");

        bool success = token.transferFrom(msg.sender,address(this),_amount);
        require(success,"Token : Transfer failed");

        _stake(msg.sender, _amount);

        return true;
    }

    function _stake(address _sender, uint256 _amount) internal {
        User storage user = users[_sender];
        Pool storage pool = poolInfo;

        require(_amount >= pool.minContrib && 
        _amount.add(user.total_invested) <= pool.maxContrib , 
        "Invalid amount!");

        user.deposits.push(UserDeposit({
            amount: _amount,
            time: uint256(block.timestamp)
        }));

        user.total_invested += _amount;
        pool.totalDeposit += _amount;

        emit Stake(_sender, _amount);
    }

    /**
    *
    * @dev claim accumulated reward for a single pool
    *
    * @return {bool} status of claim
    */
    
    function claim() public returns(bool) {
        _claim(msg.sender);
        return true;
    }


    /**
     *
     * @dev withdraw tokens from Staking
     *
     * @param {_did} id of the deposit
     * @param {_amount} amount to be unstaked
     *
     * @return {bool} Status of stake
     *
     */
    function unStake(uint8 _did, uint256 _amount) external returns(bool) {
        User storage user = users[msg.sender];
        Pool storage pool = poolInfo;
        UserDeposit storage dep = user.deposits[_did];

        require(dep.amount >= _amount,"You don't have enough funds");

        _claim(msg.sender);

        pool.totalDeposit -= _amount;
        user.total_invested -= _amount;
        dep.amount -= _amount;
        transfer(msg.sender,_amount);

        return true;
    }

    function _claim(address _addr) internal { 
        User storage user = users[_addr];

        uint256 amount = _payout(_addr);

        if(amount > 0){
            user.total_withdrawn += amount;

            safeTransfer(_addr,amount);

            user.lastPayout = block.timestamp;
        }


        emit Claim(_addr, amount);
    }

    function _payout(address _addr) public view returns(uint256 value) {
        User storage user = users[_addr];
        Pool storage pool = poolInfo;

        for(uint256 i = 0; i < user.deposits.length; i++) {
            UserDeposit storage dep = user.deposits[i];
                uint256 from = user.lastPayout > dep.time ? user.lastPayout : dep.time;
                uint256 to = block.timestamp;

                if(from < to) {
                    value += dep.amount * (to - from) * 
                    pool.apy / 365 / (1 days * 10000);
                } 
        }

        return value;
    }

    /**
     *
     * @dev safe transfer function, require to have enough token to transfer
     *
     */
    function safeTransfer(address _to, uint256 _amount) internal {
        uint256 Bal = token.balanceOf(address(0x123));
        if (_amount > Bal) {
            token.transferFrom(address(0x123),_to, Bal);
        } else {
            token.transferFrom(address(0x123),_to, _amount);
        }
    }

}