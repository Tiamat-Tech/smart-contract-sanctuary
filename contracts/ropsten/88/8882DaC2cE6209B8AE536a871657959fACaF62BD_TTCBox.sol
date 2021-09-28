// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol"; 
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol"; 


contract TTCBox is IERC20Upgradeable {

    using SafeMathUpgradeable for uint;
    using AddressUpgradeable for address;
    
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _symbol;
    string private _tokenname;
    uint8 private _decimals;

    address public admin;
    IERC20Upgradeable public BORT;
    IERC20Upgradeable public TTC;


    uint public totalDeposits;
    bool initialized;
    mapping(address => uint) public deposits;
    
    event WithdrawBORT(address, uint);
    event WithdrawTTC(address, uint);
    event Deposit(address, uint);
    event Burn(address, uint);

    modifier onlyAdmin {
        require(msg.sender == admin,"You Are not admin");
        _;
    }


    function name() public view returns (string memory) {
        return _tokenname;
    }


    function symbol() public view returns (string memory) {
        return _symbol;
    }

 
    function decimals() public view returns (uint8) {
        return _decimals;
    }

 
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }


    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }


    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }


    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }


    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }


    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }


    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }


    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }


    function initialize(address _BORTAddr) external {
        require(!initialized,"initialized");
        admin = msg.sender;
        BORT = IERC20Upgradeable(_BORTAddr);
        TTC = IERC20Upgradeable(address(this));
        initialized = true;
        _symbol = "TTC";
        _tokenname = "TTC";
        _totalSupply = 10000*10000*1e18;
        _decimals = 18;
        _balances[msg.sender] = 10000*10000*1e18;
        emit Transfer(address(0), 0xAB4537a2BF87E9F3B1CE44590fd0d67C48f7c95a, 100000000*10000*1e18);
    }


    function deposit(uint _amount) external {        
        BORT.transferFrom(msg.sender, address(this), _amount);
        deposits[msg.sender] += _amount;
        totalDeposits += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function withdrawBORT(address _userAddr, uint _amount) external onlyAdmin {
        require(_userAddr!=address(0),"Can not withdraw to Blackhole");
        BORT.transfer(_userAddr, _amount);

        emit WithdrawBORT(_userAddr, _amount);
    }


    function withdrawTTC(address _addr, uint _amount) external onlyAdmin {
        require(_addr!=address(0),"Can not withdraw to Blackhole");
        _transfer(address(this), _addr, _amount);
    }

    function batchAdminWithdrawTTC(address[] memory _userList, uint[] memory _amount) external onlyAdmin {
        for (uint i = 0; i < _userList.length; i++) {
            TTC.transfer(address(_userList[i]), uint(_amount[i]));
        }
    }

    function burnTTC(uint _amount) external onlyAdmin {
        TTC.transferFrom(msg.sender,address(0x000000000000000000000000000000000000dEaD), _amount);

        emit Burn(msg.sender, _amount);
    }

    receive () external payable {}


}