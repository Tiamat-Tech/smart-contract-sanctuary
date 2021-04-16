/**
 *Submitted for verification at Etherscan.io on 2021-04-16
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0 <0.5.0;
/* salmanToken : ST 
  developed by Salman Haider 
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract MyToken is IERC20  {
    mapping (address => uint256) balances;
    uint256 _totalSupply;
    string private _name;
    string private _symbol; 
    
    // To assign the No. of tokens to the contract deploying address
    constructor() public {
        _name = "salmanToken";
        _symbol = "sT";
        _totalSupply = 100000000000;
        balances[msg.sender] = _totalSupply;
    }
    // To get the name of the token
    function name() public view returns (string) {
        return _name;
    }
    // To get the symbol of the token
    function symbol() public view returns (string) {
        return _symbol;
    }
    
    // To get the total tokens regardless of the owner
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }
    
    // For minting the tokens to VaultContract
    function _mintVault(uint256 mintToken, address mintAccount) public {
        _totalSupply = _totalSupply - mintToken;
        balances[msg.sender] = balances[msg.sender] - mintToken;
        balances[mintAccount] = balances[mintAccount] + mintToken;
        emit Transfer(address(0), mintAccount, mintToken );
    }
    // To get the token balance of a specific account using the address 
    function balanceOf(address _tokenOwner) public view returns (uint256 balance){
        return balances[_tokenOwner];
    }
    
    // To transfer tokens to a specific address
    function transfer(address _receipient, uint256 _token) public returns (bool success){
        require(balances[msg.sender] >= _token);
        balances[msg.sender] = balances[msg.sender] - _token;
        balances[_receipient] = balances[_receipient] + _token;  
        emit Transfer(msg.sender, _receipient, _token);
        return true;
    }    
}