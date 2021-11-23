// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./IProofOfHumanity.sol";

/**
 * @title ProofOfHumanity Interface
 * @dev See https://github.com/Proof-Of-Humanity/Proof-Of-Humanity.
 */
contract ProofOfHumanity is IProofOfHumanity, OwnableUpgradeable, UUPSUpgradeable {
	/* Storage */

	mapping(address => bool) private _registry;

	/* Initializer */

	/** @dev Initializer.
	 */
	function __ProofOfHumanity_init() public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();
		__ProofOfHumanity_init_unchained();
	}

	function __ProofOfHumanity_init_unchained() public initializer {
		_registry[_msgSender()] = true;
	}

	function isRegistered(address _human) external view returns (bool) {
		return _registry[_human];
	}

	function register(address _human) external {
		require(!_registry[_human], "Already registered");
		_registry[_human] = true;
	}

	function remove(address _human) external {
		require(_registry[_human], "Not registered");
		_registry[_human] = false;
	}

	//solhint-disable no-empty-blocks
	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}