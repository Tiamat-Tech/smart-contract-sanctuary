// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./ImmutableERC721Asset.sol";

/**
 * @title Illuvial
 *
 * @notice An Illuvial is a special type of NFT, it requires metadata to be held on the server
 *      in order to show all of its features.
 *      This is different from other Collectible types which are static.
 *
 * @author Basil Gorin
 */
contract Illuvial is ImmutableERC721Asset {
	/**
	 * @inheritdoc ERC721Asset
	 */
	uint256 public constant override TOKEN_UID = 0x2863d991f820bc13d8e4b54bba81f12de57008aa13ebe15a9dc963f728583704;

	/**
	 * @dev Creates/deploys an Illuvial - Immutable ERC721 asset
	 */
	constructor() ImmutableERC721Asset("Illuvial", "ILU"){}
}