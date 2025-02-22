// SPDX-License-Identifier: MIT
// ERC 20 Token
pragma solidity ^0.7.0;
import "./MYERC20.sol";
import "./SafeMath.sol";

contract BARODAToken20 is MYERC20{
    using SafeMath for uint256;
    string public constant name = "BARODAERC20";
    string public constant symbol = "BRD20";
    uint8 public constant decimals = 5;

    mapping (address => uint256) private _balances;
    mapping (address => mapping(address => uint256)) _allowed;
    uint256 private _totalSupply = 10000000000;  
     
    function totalSupply() public view override returns (uint256){
        return _totalSupply;
    }

    function balanceOf(address _owner) public view override returns (uint256){
        return _balances[_owner];
    }

    function allowance(address _owner, address _spender) public view override returns (uint256){
        return _allowed[_owner][_spender];
    }

    function transfer(address _to, uint256 _value) public virtual override returns (bool){
        require(_to != address(0));
        require(_value <= _balances[msg.sender]);
        _balances[msg.sender] = _balances[msg.sender].sub(_value);
        _balances[_to] = _balances[_to].add(_value);        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool){
        require(_spender != address(0));
        _allowed[msg.sender][_spender] = _value;        
        emit Approval(msg.sender, _spender, _value);
        return true;
    } 
    
    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool){
        require(_to != address(0));
        require(_value <= _balances[_from]);
        require(_value <= _allowed[_from][msg.sender]);

        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value); 
        emit Transfer(_from, _to , _value);    
        return true;
    }  
}