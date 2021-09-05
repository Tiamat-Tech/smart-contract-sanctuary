// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./ImmutableERC20Asset.sol";

/**
 * @title Illuvium Resource
 *
 * @notice An Illuvium Resource is a fungible Game Element modeled as an ERC20 token.
 *
 * @author Basil Gorin
 */
contract IlluviumResource is ImmutableERC20Asset {
	/**
	 * @inheritdoc ERC20Asset
	 */
	uint256 public constant override TOKEN_UID = 0xb0f10c95165aca48ea8a02c30a5a805d76eed0fb0b9eff02ec0fe3741494b74b;

	/**
	 * @dev Creates/deploys an Illuvium Resource - Immutable ERC20 asset
	 *
	 * @param _name asset name
	 * @param _symbol asset symbol
	 */
	constructor(string memory _name, string memory _symbol) ImmutableERC20Asset(_name, _symbol) {}
}