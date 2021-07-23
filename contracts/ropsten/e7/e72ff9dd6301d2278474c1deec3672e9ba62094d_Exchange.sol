/**
 *Submitted for verification at Etherscan.io on 2021-07-20
*/

//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;
library SafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath : subtraction overflow");
        uint256 c = a - b;
        return c;
    }
}
interface Token {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address _to, uint256 _amount) external returns(bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mint(address _to, uint256 _amount) external;
    function burn(address _to, uint256 _amount) external;
}
contract Exchange {
  event Order(address tokenBuy, uint256 amountBuy, address tokenSell, uint256 amountSell, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s);
  event Cancel(address tokenBuy, uint256 amountBuy, address tokenSell, uint256 amountSell, uint256 expires, uint256 nonce, address user, uint8 v, bytes32 r, bytes32 s);
  event Trade(address tokenBuy, uint256 amountBuy, address tokenSell, uint256 amountSell, address get, address give);
  event Deposit(address token, address user, uint256 amount, uint256 balance);
  event Withdraw(address token, address user, uint256 amount, uint256 balance);
    //using SafeMath for uint256;
    function safeMul(uint a, uint b) internal pure returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

    function safeSub(uint a, uint b) internal pure returns (uint) {
    assert(b <= a);
    return a - b;
  }

    function safeAdd(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }
     
    mapping (address => mapping (address => uint256)) public tokens; 
  
    function depositToken(address token, uint256 amount) public {
        require(amount>0,"Amount must be greater than zero");
        require(token!=address(0),"Invalid address");
        tokens[token][msg.sender] = safeAdd(tokens[token][msg.sender], amount);
        Token(token).transferFrom(msg.sender, address(this), amount); 
        emit Deposit(token, msg.sender, amount, tokens[token][msg.sender]);
  }

    function deposit() public payable {
        require(msg.value>0,"Value must be greater than zero");
        tokens[address(0)][msg.sender] = safeAdd(tokens[address(0)][msg.sender], msg.value);
        emit Deposit(address(0), msg.sender, msg.value, tokens[address(0)][msg.sender]);
    }

    function withdraw(address token, uint256 amount) public {
        require(amount>0,"Amount must be greater than zero");
        require(tokens[token][msg.sender] >= amount,"Not Enough balance");
        tokens[token][msg.sender] = safeSub(tokens[token][msg.sender], amount);
        
        if (token == address(0)) {
          payable(msg.sender).transfer(amount);
        } 
        
        else {
          Token(token).transfer(msg.sender, amount);
        }
        
        emit Withdraw(token, msg.sender, amount, tokens[token][msg.sender]);
    }
}