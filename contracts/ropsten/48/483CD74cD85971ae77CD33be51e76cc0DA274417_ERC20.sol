// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./IERC20.sol";

contract ERC20 is IERC20{
    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;
    uint256 public totalSupply;
    string public name;
    string public symbol;
    address public owner;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function balanceOf(address _account) public view virtual override returns (uint256) {
        return balances[_account];
    }

    function transfer(address _to, uint256 _amount) public virtual override returns (bool) {
        _transfer(msg.sender, _to, _amount);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _amount) internal virtual {
        require(_from != address(0), "Transfer from the zero address");
        require(_to != address(0), "Transfer to the zero address");
        
        require(balances[_from] >= _amount, "Transfer amount exceeds balance");
        balances[_from] = balances[_from] - _amount;
        balances[_to] += _amount;

        emit Transfer(_from, _to, _amount);
    }
    
    function allowance(address _owner, address spender) public view virtual override returns (uint256) {
        return allowances[_owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address _owner,address spender,uint256 amount) internal virtual {
        require(_owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transferFrom(address _from, address _to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = allowances[_from][msg.sender];
        
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Amount exceeds allowance");
            _approve(_from, msg.sender, currentAllowance - amount);
        }

        _transfer(_from, _to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, allowances[msg.sender][spender] + addedValue);
        return true;
    }

     function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        require(allowances[msg.sender][spender] >= subtractedValue, "Decreased allowance below zero");

        _approve(msg.sender, spender, allowances[msg.sender][spender] - subtractedValue);

        return true;
    }

    function mint(address _to, uint256 _amount) public virtual onlyOwner returns (bool){
        _mint(_to, _amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "Mint to the zero address");
        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) public virtual returns (bool){
        _burn(account, amount);
        return true;
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "Burn from the zero address");
        require(balances[account] >= amount, "Burn amount exceeds balance");
        balances[account] = balances[account] - amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
}