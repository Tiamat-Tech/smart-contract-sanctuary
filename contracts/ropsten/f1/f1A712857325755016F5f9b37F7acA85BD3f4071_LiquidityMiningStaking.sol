// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

//import "./interfaces/IContractsRegistry.sol";
import "./StkBMIToken.sol";

contract BMIStaking is Ownable {
	using SafeMath for uint256;

	//IContractsRegistry public contractsRegistry;

	IERC20 public bmiToken;
	StkBMIToken public stkBMIToken;

	event StakedBMI(uint256 stakedBMI, uint256 mintedStkBMI, address indexed recipient);
	event WithdrawnBMI(
		uint256 withdrawnBMI,
		uint256 burnedStkBMI,
		address indexed recipient
	);

	// function initRegistry(IContractsRegistry _contractsRegistry)
	// 	external
	// 	onlyOwner
	// {
	// 	contractsRegistry = _contractsRegistry;

	// 	bmiToken = IERC20(_contractsRegistry.getBMIContract());
	// 	stkBMIToken = StkBMIToken(_contractsRegistry.getStkBMIContract());
	// }

	function initTokens(address _bmiToken, address _stkBMIToken)
		external
		onlyOwner
	{
		bmiToken = IERC20(_bmiToken);
		stkBMIToken = StkBMIToken(_stkBMIToken);
	}

	function stake(uint256 _amountBMI) external {
		require(
			bmiToken.transferFrom(_msgSender(), address(this), _amountBMI),
			"Staking: Failed to transfer BMI tokens"
		);

		uint256 amountStkBMI = _convertToStkBMI(_amountBMI);
		stkBMIToken.mint(_msgSender(), amountStkBMI);

		emit StakedBMI(_amountBMI, amountStkBMI, _msgSender());
	}

	function withdraw(uint256 _amountStkBMI) external {
		require(
			stkBMIToken.balanceOf(_msgSender()) >= _amountStkBMI,
			"Withdraw: not enough stkBMI tokens to withdraw"
		);

		uint256 amountBMI = _convertToBMI(_amountStkBMI);
		stkBMIToken.burn(_msgSender(), _amountStkBMI);

		require(
			bmiToken.transfer(_msgSender(), amountBMI),
			"Withdraw: failed to transfer BMI tokens"
		);

		emit WithdrawnBMI(amountBMI, _amountStkBMI, _msgSender());
	}

	function stakingReward(uint256 _amount) public view returns (uint256) {
		return _convertToBMI(_amount);
	}

	function getStakedBMI(address _address) public view returns (uint256) {
		uint256 balance = stkBMIToken.balanceOf(_address);
		return balance > 0 ? _convertToBMI(balance) : 0;
	}

	function _convertToStkBMI(uint256 _amount) internal view returns (uint256) {
		uint256 TSstkBMIToken = stkBMIToken.totalSupply();
		uint256 stakingPoolBalance = bmiToken.balanceOf(address(this));

		if (stakingPoolBalance > 0 && TSstkBMIToken > 0) {
			_amount = TSstkBMIToken.mul(_amount).div(stakingPoolBalance);
		}

		return _amount;
	}

	function _convertToBMI(uint256 _amount) internal view returns (uint256) {
		uint256 TSstkBMIToken = stkBMIToken.totalSupply();
		uint256 stakingPoolBalance = bmiToken.balanceOf(address(this));

		_amount = stakingPoolBalance.mul(_amount).div(TSstkBMIToken);

		return _amount;
	}
}