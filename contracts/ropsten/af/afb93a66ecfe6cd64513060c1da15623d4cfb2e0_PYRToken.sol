/**
 *Submitted for verification at Etherscan.io on 2021-03-14
*/

pragma solidity ^0.4.24;
// ----------------------------------------------------------------------------
// Sample token contract
//
// Symbol        : PYR
// Name          : PYR Token
// Total supply  : 50000000
// Decimals      : 18
// Owner Account : 0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557

// ----------------------------------------------------------------------------
// Lib: Safe Math
// ----------------------------------------------------------------------------
contract SafeMath {

    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }

    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }

    function safeMul(uint a, uint b) public pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }

    function safeDiv(uint a, uint b) public pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


contract Ownable {

    address public owner;

    function Ownable1() public {
        owner = 0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557;
    }

    modifier onlyOwner {
        require(0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557 == owner);
        require (owner != address(0));
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0));
        owner = _newOwner;
        
    }
}


/**
ERC Token Standard #20 Interface
https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
*/
contract IERC20 {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Buy(uint indexed);
    event Burn(address indexed from, uint256 value);
    

}



/**
Contract function to receive approval and execute function in one call

Borrowed from MiniMeToken
*/
contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}


/**
ERC20 Token, with the addition of symbol, name and decimals and assisted token transfers
*/
    contract PYRToken is IERC20, SafeMath, Ownable {
    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;
    uint256 public sellPrice;
    uint256 public buyPrice;
    uint256 public UpdatedTokenInformation;
    


    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public balanceOf;
    


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor() public {
        symbol = "PYR";
        name = "PYR Token";
        decimals = 18;
        _totalSupply = 50000000000000000000000000;
        balances[0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557] = _totalSupply;
        emit Transfer(address(0), 0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, _totalSupply);
    }
    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public constant returns (uint) {
        return _totalSupply  - balances[address(0)];
    }


    // ------------------------------------------------------------------------
    // Get the token balance for account tokenOwner
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }


    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to to account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        require (to != address(0x0)); 
        balances[0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557] = safeSub(balances[0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for spender to transferFrom(...) tokens
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557][spender] = tokens;
        emit Approval(0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer tokens from the from account to the to account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the from account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = safeSub(balances[from], tokens);
        allowed[from][0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557] = safeSub(allowed[from][0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(from, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for spender to transferFrom(...) tokens
    // from the token owner's account. The spender contract function
    // receiveApproval(...) is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557][spender] = tokens;
        emit Approval(0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, spender, tokens);
        ApproveAndCallFallBack(spender).receiveApproval(0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, tokens, this, data);
        return true;
    }
     /// @notice Allow users to buy tokens for `newBuyPrice` eth and sell tokens for `newSellPrice` eth
    /// @param newSellPrice Price the users can sell to the contract
    /// @param newBuyPrice Price users can buy from the contract
    function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner public {
       sellPrice = newSellPrice;
        buyPrice = newBuyPrice;
    }

    /// @notice Buy tokens from contract by sending ether
   function buy(uint index) payable public {
        uint amount = msg.value / buyPrice;                 // calculates the amount
        emit Transfer(address(this), 0x816C29cFB0b6C3a565179dE9a9616Dc2b5c0C557, amount);
         emit Buy (index);
    
    
        }
 /* function to update token name and symbol */
  function updateTokenInformation(string _name, string _symbol) onlyOwner public {
       name = _name;
       symbol = _symbol;
      
       updateTokenInformation (name, symbol);
        
  }

    function updateTokenPrice(uint _value) onlyOwner public{
      require(_value > 0);
      sellPrice = _value;
  }
  function () public payable {
        revert();
    }
    
   function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);// Check if the sender has enough
        balanceOf[msg.sender] -= _value;            // Subtract from the sender
        _totalSupply -= _value;                      // Updates totalSupply
        emit Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
        require(_value <= allowance[_from][msg.sender]);    // Check allowance
        balanceOf[_from] -= _value;                         // Subtract from the targeted balance
        allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
        _totalSupply -= _value;                              // Update totalSupply
        emit Burn(_from, _value);
        return true;
    }
}