/**
 *Submitted for verification at Etherscan.io on 2021-12-01
*/

pragma solidity ^0.8.3;
// SPDX-License-Identifier: GPL-3.0
library SafeMath { // Only relevant functions
function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256)   {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract AxTkn{
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    using SafeMath for uint256;
    address owner_;
    uint256 totalSupply_;

    constructor(uint256 total)  {
        owner_ = msg.sender;
        totalSupply_ = total;
        balances[msg.sender] = totalSupply_;
    }

    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }

    event Approval(address indexed tokenOwner, address indexed spender,  uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

    string public constant name = "AXPEROTTO";
    string public constant symbol = "AXP";
    uint8 public constant decimals = 0;

    function totalSupply() public view returns (uint256){ return totalSupply_; }

    function allowance(address owner,
                  address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }
    
    function store() payable public {
    }


    modifier _ownerOnly(){
        require(msg.sender == owner_);
        _;
    }

    function sellToken(uint256 numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);

        (bool sent, bytes memory data) = msg.sender.call{value: numTokens}("");
        require(sent, "Failed to send Ether");
        return true;
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate,
                uint numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);
        require(numTokens <= allowed[owner][msg.sender]);
        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] =  allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}