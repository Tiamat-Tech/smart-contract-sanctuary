pragma solidity ^0.8.0;

import "./base_contracts/ERC20Burnable.sol";
import "./base_contracts/Ownable.sol";

/*
abstract contract ERC20Token {

    function totalSupply() public virtual view returns (uint256);
    function balanceOf(address tokenOwner) public virtual view returns (uint256);
    function allowance(address tokenOwner, address spender) public virtual view returns (uint256);
    function transfer(address to, uint256 tokens) public virtual returns (bool);
    function approve(address spender, uint256 tokens)  public virtual returns (bool);
    function transferFrom(address from, address to, uint256 tokens) public virtual returns (bool);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ZToken is ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;
    
    uint256 _totalSupply;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    
    constructor (uint256 total) {
        _totalSupply = total;
        _balances[msg.sender] = _totalSupply;
        
        name = "Z Token";
        symbol = "ZT";
        decimals = 18;
    }
    
    function totalSupply() public override view returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return _balances[tokenOwner];
    }
    
    function allowance(address tokenOwner, address spender) public override view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }
    
    function transfer(address to, uint256 tokens) public override returns (bool) {
        require(tokens <= _balances[msg.sender]);
        _balances[msg.sender] -= tokens;
        _balances[to] += tokens;
        emit Transfer(msg.sender, to, tokens);
        return true;    
    }
    
    function approve(address spender, uint256 tokens) public override returns (bool) {
        _allowances[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 tokens) public override returns (bool) {
        require(tokens <= _balances[msg.sender]);
        require(tokens <= _allowances[from][msg.sender]);
        
        _balances[msg.sender] -= tokens;
        _allowances[from][msg.sender] -= tokens;
        _balances[to] += tokens;
        
        emit Transfer(from, to, tokens);
        return true;    
    }
}*/

contract ZToken is ERC20Burnable, Ownable {

    constructor(uint256 amount) ERC20("Z Token", "ZTK") {
        mint(amount * 10 ** decimals());
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(_msgSender(), amount);
    }

    function decimals() public pure override returns (uint8) {
        return 9;
    }
}