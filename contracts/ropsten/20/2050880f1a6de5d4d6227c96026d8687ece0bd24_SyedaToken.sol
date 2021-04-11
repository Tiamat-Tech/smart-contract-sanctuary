/**
 *Submitted for verification at Etherscan.io on 2021-04-11
*/

// "SPDX-License-Identifier: UNLICENSED"
 pragma solidity ^0.6.6;
 
 interface ERC20Interface {
   function totalSupply() external view returns (uint256);
   function balanceOf(address account) external view returns (uint256);
   function allowance(address owner, address spender) external view returns (uint256);
   function transfer(address recipient, uint256 amount) external returns (bool);
   function approve(address spender, uint256 amount) external returns (bool);
   function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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

contract SyedaToken is ERC20Interface {
    using SafeMath for uint256;
    
    string public symbol;
    string public name;
    uint8 public decimals;
    uint public _totalSupply;
    address public tokenOwner;
    
    mapping(address => uint) private _balances;
    address[] private _distributors;
    mapping(address => mapping(address => uint256)) private _allowances;
    event AmountDistribute(address indexed from, address[] indexed to, uint256 value);

    constructor() public {
        tokenOwner = msg.sender;
        symbol="SH88"; // ADD YOUR OWN SYMBOL HERE 
        name=""; // ADD YOUR OWN NAME HERE 
        decimals=18;
        _totalSupply = 1000000 * 10**uint(decimals);
        _balances[tokenOwner] = _totalSupply;
        emit Transfer(address(0), tokenOwner, _totalSupply);
    }
    
    function totalSupply() public view override returns (uint256) {
        return _totalSupply - _balances[address(0)];
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    // new
    function distributeSupply(address[] memory addresses) public virtual returns (bool) {
        address sender = msg.sender;
        require (msg.sender == tokenOwner, "Only owner can transfer funds");
        require (_balances[sender] > 0, "Not enough balance");
        
        uint fivePercentMul = _balances[sender].mul(5);
        uint fivePercent = fivePercentMul.div(100);
        uint amountToDistribute = fivePercent.div(addresses.length);
        _balances[sender] = _balances[sender].sub(fivePercent, "transfer amount exceeds balance");
        for(uint i=0; i<addresses.length; i++) {
            _balances[addresses[i]] = _balances[addresses[i]].add(amountToDistribute);
            _distributors.push(addresses[i]);
            emit Transfer(tokenOwner, addresses[i], amountToDistribute);
        }
        return true;
    }
    
    // new 
    function getDistributors() external view returns (address[] memory distributors) {
        return (_distributors);
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        address sender = msg.sender;
        
        _balances[sender] = _balances[sender].sub(amount, "transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address sender = msg.sender;
        
        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        
        _balances[sender] = _balances[sender].sub(amount, "transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        
        _allowances[sender][recipient] = amount;
        emit Approval(sender, recipient, amount);
        return true;
    }
}