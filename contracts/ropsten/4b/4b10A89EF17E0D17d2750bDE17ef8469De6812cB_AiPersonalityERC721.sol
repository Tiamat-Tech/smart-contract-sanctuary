// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./TinyERC721.sol";

/**
 * @title AI Personality
 *
 * @notice AI Personality replaces AI Pod in version 2 release, it doesn't
 *      store any metadata on-chain, all the token related data except URI
 *      (rarity, traits, etc.) is expected to be stored off-chain
 *
 * @dev AI Personality is a Tiny ERC721, it supports minting and burning,
 *      its token ID space is limited to 32 bits
 *
 * @author Basil Gorin
 */
contract AiPersonalityERC721 is TinyERC721 {
	/**
	 * @inheritdoc TinyERC721
	 */
	uint256 public constant override TOKEN_UID = 0xd9b5d3b66c60255ffa16c57c0f1b2db387997fa02af673da5767f1acb0f345af;

	/**
	 * @dev Constructs/deploys AI Personality instance
	 *      with the predefined name and symbol
	 */
	// TODO: finalize token name and symbol with Alethea
	// TODO: #7 Each contract name of AI Personality for the collection will be different - need to decide name for 10k campaign
	constructor() TinyERC721("AI Personality", "PER") {}
}