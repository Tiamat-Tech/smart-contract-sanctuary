/**
 *Submitted for verification at Etherscan.io on 2021-05-15
*/

pragma solidity >=0.4.20;

contract ERC20Interface {
      string public name;
      string public symbol;
      uint8  public decimals;
      uint   public totalsupply;

    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);



    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender)  view returns (uint256 remaining);



    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _Owner, address indexed _spender, uint256 _value);
}

contract ERC20 is ERC20Interface {
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) allowed;
    
    constructor() public {
      name = "zhangli";
      symbol = "ZL";
      decimals = 0;
      totalsupply = 1000000000;
      balanceOf[msg.sender] = totalsupply;
    
    }
    
    function transfer(address _to, uint256 _value) returns (bool success){
        require(_to != address(0));
        require(balanceOf[msg.sender] >= _value);
        require(balanceOf[ _to] + _value >= balanceOf[ _to]); 


        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        
         emit Transfer(msg.sender, _to, _value);

         return true;
        }
        
        
        
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success){
        require(_to != address(0));
        require(allowed[_from][msg.sender] >= _value);
        require(balanceOf[_from] >= _value);
        require(balanceOf[ _to] + _value >= balanceOf[ _to]); 


        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;

        allowed[_from][msg.sender] -= _value;
         
        emit Transfer(msg.sender, _to, _value);

         return true;
        }


    function approve(address _spender, uint256 _value) returns (bool success){
            allowed[msg.sender][_spender] = _value;
            
            emit Approval(msg.sender,_spender,_value);
            return true;
        }
        
        
    function allowance(address _owner, address _spender)  view returns (uint256 remaining){
            return allowed[_owner][_spender];
        }
    
}