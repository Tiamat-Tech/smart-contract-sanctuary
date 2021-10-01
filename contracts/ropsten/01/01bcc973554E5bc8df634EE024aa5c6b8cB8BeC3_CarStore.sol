// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/utils/Address.sol";
import "./openzeppelin/utils/ReentrancyGuard.sol";

contract CarStore is Ownable, ReentrancyGuard {
	event LogCarAdded(address indexed carId, uint256 price);

	event LogCarSold(address indexed carId, uint256 price);

	address wallet;
	mapping(address => uint256) cars;

	constructor() {
		wallet = msg.sender;
	}

	function AddCar(address carId, uint256 price) public onlyOwner {
		require(price > 0, "NO_PRICE_PROVIDED");
		require(cars[carId] == 0, "CAR_ALREADY_IN_STOCK");
		cars[carId] = price;
		emit LogCarAdded(carId, price);
	}

	function BuyCar(address carId) external payable nonReentrant {
		require(cars[carId] > 0, "INVALID_CAR");
		require(cars[carId] == msg.value, "INVALID_PARAM");
		require(wallet != msg.sender, "REALLY??");

		// first set price to prevent reentrancy
		cars[carId] = 0;
		// we just use call to catch gas problems:
		// (bool success, ) = this.call{ value: msg.value }("");
		// require(success, "Failed to send Ether");
		// but we can do the same just using OZ address lib
		Address.sendValue(payable(wallet), msg.value);

		emit LogCarSold(carId, msg.value);
	}
}