// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./TinyERC721.sol";

/**
 * @title Althea NFT
 *
 * @notice Alethea NFT is an ERC721 token used as a target NFT for iNFT protocol
 *
 * @dev Alethea NFT is a Tiny ERC721, it supports minting and burning,
 *      its token ID space is limited to 32 bits
 *
 * @author Basil Gorin
 */
contract AletheaNFT is TinyERC721 {
	/**
	 * @inheritdoc TinyERC721
	 */
	uint256 public constant override TOKEN_UID = 0x275ee64af649fe998ccbaec4f443dc216eef3bab6f11080eeeedfbdd303c59a6;

	/**
	 * @dev Constructs/deploys AI Personality instance
	 *      with the predefined name and symbol
	 */
	// TODO: finalize token name and symbol with Alethea
	constructor() TinyERC721("Alethea NFT", "ALE") {}
}