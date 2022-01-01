/**
 *Submitted for verification at Etherscan.io on 2022-01-01
*/

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1

pragma solidity ^0.8.0;

contract Context {
	function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract GoldenDogeETH is Context, Ownable {
    using SafeMath for uint256;

	event Transfer(address indexed from, address indexed to, uint256 value);

	event Approval(address indexed owner, address indexed spender, uint256 value);

	event BridgeQuotaUpdated(address indexed bridge, uint256 quota);

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    struct Bridge {
    	uint256 quota;
    	uint256 used;
    }

    mapping(address => Bridge) public bridges;

    uint256 private _totalSupply;
    uint8 private constant DECIMALS = 9;
    uint256 private constant MAX_SUPPLY = 10**17 * 10**DECIMALS;
    string private _symbol;
    string private _name;

    constructor() public {
        _name = "Golden Doge";
        _symbol = "GDOGE";
        _totalSupply = 0;
    }

    function updateBridgeQuota(address bridgeAddress, uint256 quota_) external onlyOwner {
    	bridges[bridgeAddress].quota = quota_;
    	emit BridgeQuotaUpdated(bridgeAddress, quota_);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() external view returns (uint8) {
        return DECIMALS;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "GoldenDogeETH: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "GoldenDogeETH: decreased allowance below zero"));
        return true;
    }

    function mint(address to, uint256 amount) external returns (bool) {
    	Bridge storage bridge = bridges[_msgSender()];
    	require(bridge.quota > 0, "GoldenDogeETH: only bridges can mint");
    	bridge.used = bridge.used.add(amount);
    	require(bridge.used <= bridge.quota, "GoldenDogeETH: insufficient unused quota");
        _mint(to, amount);
        return true;
    }

    function burn(address from, uint256 amount) external returns (bool) {
    	Bridge storage bridge = bridges[_msgSender()];
    	require(bridge.quota > 0, "GoldenDogeETH: only bridges can burn");
    	if (from != _msgSender()) {
	        _approve(from, _msgSender(), _allowances[from][_msgSender()].sub(amount, "GoldenDogeETH: burn amount exceeds allowance"));
	    }
    	bridge.used = bridge.used.sub(amount);
    	_burn(from, amount);
    	return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "GoldenDogeETH: transfer from the zero address");
        require(recipient != address(0), "GoldenDogeETH: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount, "GoldenDogeETH: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "GoldenDogeETH: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        require(_totalSupply <= MAX_SUPPLY, "GoldenDogeETH: reach max supply");
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "GoldenDogeETH: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "GoldenDogeETH: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "GoldenDogeETH: approve from the zero address");
        require(spender != address(0), "GoldenDogeETH: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "GoldenDogeETH: burn amount exceeds allowance"));
    }
}