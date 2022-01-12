// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ICO is Ownable {
	using SafeMath for uint256;
	
	uint8[3] _rates = [42, 21, 8];
	uint256 _start;
	uint256 _deadline1;
	uint256 _deadline2;
	uint256 _deadline3;
	uint256 tokens_available = 10000;
	ERC20 _token;
	address payable _wallet;
	
	constructor(ERC20 token) {
		_start = block.timestamp;
		_deadline1 = _start + 3 days;
		_deadline2 = _deadline1 + 30 days;
		_deadline3 = _deadline2 + 2 weeks;
		_wallet = payable(msg.sender);
		_token = token;
	}
	
	modifier whenSaleIsActive() {
		require(block.timestamp >= _start && block.timestamp < _deadline3);
		_;
	}
	
	function _calculateRateIdx(uint256 currTime) private view returns (uint8) {
		if (currTime < _deadline1) {
			return 0;
		} else if (currTime < _deadline2) {
			return 1;
		} else {
			return 2;
		}
	}
	
	function buy() public payable whenSaleIsActive {
		uint256 weiAmount = msg.value;
		uint8 rate = _rates[_calculateRateIdx(block.timestamp)];
		uint256 tokens = (weiAmount / 1 ether).mul(rate);
    
		_token.transfer(msg.sender, tokens);   
		_wallet.transfer(msg.value);
	}
	
	function getDeadline() public view returns (uint256) {
		return _deadline3;
	}
}