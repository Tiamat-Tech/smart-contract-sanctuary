// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./ImmutableERC721Asset.sol";

/**
 * @title Illuvium Collectible
 *
 * @notice An Illuvium Collectible is a non-fungible Game Element that is stored as an NFT.
 *      Collectibles are static and do not change their metadata.
 *
 * @author Basil Gorin
 */
contract IlluviumCollectible is ImmutableERC721Asset {
	/**
	 * @inheritdoc ERC721Asset
	 */
	uint256 public constant override TOKEN_UID = 0x4e1c8ef2bfca8b49f9abd586ef7c669a0e6f0301b5cb431561d53d11a0a9374b;

	/**
	 * @dev Creates/deploys an Illuvium Collectible - Immutable ERC721 asset
	 */
	constructor() ImmutableERC721Asset("Illuvium Collectible", "ILC"){}
}