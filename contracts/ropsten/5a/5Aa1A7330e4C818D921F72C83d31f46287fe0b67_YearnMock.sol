pragma solidity ^0.7.5;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract YearnMock is VaultAPI {

	using SafeMath for uint256;

	// uint8 _decimals = 18;
	uint256 price = 1000000000000000000;
	ERC20 public dai;                      // DAI token interface

	mapping(address => uint256) public balances;                       // Records balances.
	mapping(address => mapping(address => uint256)) public allowed;    // Records allowances for tokens.

	event Transfer(address from, address to, uint256 value);

	event Approval(address owner, address spender, uint256 value);

	constructor(address _dai) {
		dai = ERC20(_dai);
	}

	function pricePerShare() external override view returns (uint256) {
		return price;
	}

	// increases price for 10%
	function _updatePrice() external {
		price += 1000000000000000000;
	}

	// function decimals() public view override returns (uint8) {
	//     return _decimals;
	// }

	function deposit(uint256 amount) external override returns (uint256) {
		return _deposit(msg.sender, amount);
	}

	function withdraw(uint256 amount) external override returns (uint256) {
		return _withdraw(msg.sender, amount);
	}

	function withdraw(uint256 amount, address receiver) external override returns (uint256) {
		return _withdraw(amount, receiver);
	}

	function _deposit(address depositor, uint256 amount) internal returns (uint256 deposited) {
		deposited = amount;
		dai.transferFrom(depositor, address(this), amount);
	}

	function _withdraw(
		address receiver,
		uint256 amount
	) internal returns (uint256 withdrawn) {
		uint256 reward = 10000000000000000000;
		withdrawn = amount + reward;

		require(dai.balanceOf(address(this)) >= withdrawn, "not enought dai");

		dai.transfer(receiver, withdrawn);
	}

	function _withdraw(
		uint256 amount,
		address receiver
	) internal returns (uint256 withdrawn) {
		uint256 reward = 10000000000000000000;
		withdrawn = amount + reward;
		dai.transfer(receiver, withdrawn);
	}

	//    function allowance(
	//     address _owner,
	//     address _spender
	// )
	//     public
	//     view
	//     returns (uint256)
	// {
	//     return allowed[_owner][_spender];
	// }

	// function approve(address _spender, uint256 _value) public returns (bool) {
	//     allowed[msg.sender][_spender] = _value;

	//     emit Approval(msg.sender, _spender, _value);        // Records in Approval event.

	//     return true;
	// }

	function transferFrom(
		address _from,
		address _to,
		uint256 _value
	)
		public
		returns (bool)
	{
		require(allowed[_from][msg.sender] >= _value, "Insufficient allowance"); // Requires allowance for sufficient amount of tokens to send.
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);     // Decreases amount of allowed tokens for sended value.

		_transfer(_from, _to, _value);                                           // Calls _transfer function.
		return true;
	}

	function _transfer(address _from, address _to, uint256 _value) internal {
		require(balances[_from] >= _value, "Insufficient balance"); // Requires balance to be sufficient enough for transfer.
		balances[_from] = balances[_from].sub(_value);              // Decreases balances of sender.
		balances[_to] = balances[_to].add(_value);                  // Increases balances of recipient.

		emit Transfer(_from, _to, _value);                          // Records transfer to Transfer event.
	}
}