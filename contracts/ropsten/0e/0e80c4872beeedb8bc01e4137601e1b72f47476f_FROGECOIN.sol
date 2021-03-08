/**
 *Submitted for verification at Etherscan.io on 2021-03-08
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function totalMinted() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}
contract FROGECOIN is IERC20 {

    string public constant name = "FROGE";
    string public constant symbol = "FROGE";
    uint8 public constant decimals = 18;

    event Mint(address indexed to, uint256 amount);	
    mapping(address => uint256) balances;
	
	address public owner;
    uint256 totalSupply_;
    uint256 minted_;
    using SafeMath for uint256;
	
	constructor(uint256 total) {
		totalSupply_ = total;
		minted_ = 3000000000000000000000000;
		balances[msg.sender] = 3000000000000000000000000;
		owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
	
    function totalSupply() public override view returns (uint256) {
		return totalSupply_;
    }
    
    function totalMinted() public override view returns (uint256) {
		return minted_;
    }
	
    function balanceOf(address tokenOwner) public override view returns (uint256) {
        return balances[tokenOwner];
    }
	
    function transfer(address receiver, uint256 numTokens) public override returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(numTokens);
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }
    
    function mint(address receiver, uint256 numTokens) public onlyOwner returns (bool) {
        minted_ = minted_.add(numTokens);
        require(minted_ <= totalSupply_);
        
        balances[receiver] = balances[receiver].add(numTokens);
        emit Mint(receiver, numTokens);
        return true;
    }
	
}

library SafeMath {
	
	function fxpMul(uint256 a, uint256 b, uint256 base) internal pure returns (uint256) {
		return div(mul(a, b), base);
	}
		
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a, "SafeMath: addition overflow");
		return c;
	}

	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a, "SafeMath: subtraction overflow");
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
		require(b > 0, "SafeMath: division by zero");
		uint256 c = a / b;
		return c;
	}
}