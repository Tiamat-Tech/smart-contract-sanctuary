// contracts/AdminBox.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AdminBox is Initializable, UUPSUpgradeable, OwnableUpgradeable {
	mapping(address => uint256) public values;
	bool public initialized;
	modifier onlyInitialized() {
		require(initialized, "NOT INIT");
		_;
	}

	// Emitted when the stored value changes
	event ValueChanged(address indexed user, uint256 value);

	function initialize() public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		initialized = true;
	}

	// Stores a new value in the contract
	function store(address user, uint256 value) public onlyOwner onlyInitialized {
		values[user] = value;
		emit ValueChanged(user, value);
	}

	function _authorizeUpgrade(address) internal override onlyOwner onlyInitialized {}
}