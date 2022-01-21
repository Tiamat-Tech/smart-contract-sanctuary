// SPDX-License-Identifier: GNU-3
pragma solidity =0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Registry.sol";
import "./dapphub/DSAuthority.sol";

/// @title Authority contract managing proxy permissions
/// @notice Proxy will ask Authority for permission to execute received message.
contract Authority is Ownable, DSAuthority {

	/// @notice Registry gatekeeper id
	bytes32 constant GATEKEEPER_ID = keccak256("Gatekeeper");

	/// @notice Apus registry address
	address immutable registry;


	constructor(address _registry) Ownable() {
		registry = _registry;
	}


	/// @notice Called by proxy to determine if sender is allowed to make a message call
	/// @dev Currently are allowed only messages from gatekeeper
	/// @dev Authority contract cannot forbid proxy owner from calling arbitrary messages
	function canCall(address src, address dst, bytes4 sig) override public view returns (bool) {
		return src == Registry(registry).getAddress(GATEKEEPER_ID);
	}

}