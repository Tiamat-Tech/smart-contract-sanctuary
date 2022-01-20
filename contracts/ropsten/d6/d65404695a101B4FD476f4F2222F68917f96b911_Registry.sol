// SPDX-License-Identifier: GNU-3
pragma solidity =0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Registry contract for whole Apus ecosystem
/// @notice Holds addresses of all essential Apus contracts
contract Registry is Ownable {

	/// @notice Stores address under its id
	/// @dev Id is keccak256 hash of its string representation
	mapping (bytes32 => address) public addresses;

	/// @notice Emit when owner registers address
	/// @param id Keccak256 hash of its string id representation
	/// @param previousAddress Previous address value under given id
	/// @param newAddress New address under given id
	event AddressRegistered(bytes32 indexed id, address indexed previousAddress, address indexed newAddress);


	constructor() Ownable() {

	}


	/// @notice Getter for registered addresses
	/// @dev Returns zero address if address have not been registered before
	/// @param _id Registered address identifier
	function getAddress(bytes32 _id) external view returns(address) {
		return addresses[_id];
	}


	/// @notice Register address under given id
	/// @dev Only owner can register addresses
	/// @dev Emits `AddressRegistered` event
	/// @param _id Keccak256 hash of its string id representation
	/// @param _address Registering address
	function registerAddress(bytes32 _id, address _address) external onlyOwner {
		require(_address != address(0), "Registered address cannot be zero address");
		address _previousAddress = addresses[_id];
		addresses[_id] = _address;
		emit AddressRegistered(_id, _previousAddress, _address);
	}
}