pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";

/// @title ZooNft Contract with minter and pauser roles.
/// @notice based on OpenZeppelin's ERC721PresetMinterPauserAutoId.
contract ZooNft is Context, AccessControl, ERC721Burnable, ERC721Pausable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdTracker;                   // Token id tracker.

	mapping(string => uint8) hashes;							// Records what hash was used.

	/// @notice Contract constructor.
	/// @notice Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the account that deploys the contract.
    /// @notice See {ERC721-tokenURI}.
    /// @param name - name of contract.
    /// @param symbol - symbol of contract.
    /// @param baseURI - baseURI part of nft hash.
    constructor(string memory name, string memory symbol, string memory baseURI) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        _setBaseURI(baseURI);
    }

	/// @notice Creates new Nft token, requires minter role, generate URI from baseURI and hash of metadata.
	/// @param to - address recipient of token.
	/// @param hash - hash of the image.
	/// @param metadata - hash of the metadata of the asset.
    function mint(address to, string memory hash, string memory metadata, string memory _element) public returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "must have minter role to mint"); // Requires minter role to mint.

		require((hashes[hash] != 1), "Hash is already used!");  // Requires hash to be non-used before.

		hashes[hash] = 1;										// Records that hash became in use.

		uint256 tokenId = _tokenIdTracker.current();			// Calls Id for nft.
		string memory element = _element;//test

        _mint(to, tokenId);										// Calls _mint function
        _tokenIdTracker.increment();							// Increments id.
		_setTokenURI(tokenId, metadata);						// Matches token uri for token id.

		return tokenId;                                         // Returns id of token.
	}

	/// @notice Pauses all token transfers.
   	/// @notice See {ERC721Pausable} and {Pausable-_pause}.
    /// @notice The caller must have the `PAUSER_ROLE`.
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "must have pauser role to pause"); // Requires pauser role to pause.
        _pause();                                                                      // Calls pause function.
    }

    /// @notice Unpauses all token transfers.
    /// @notice See {ERC721Pausable} and {Pausable-_unpause}.
    /// @notice The caller must have the `PAUSER_ROLE`.
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "must have pauser role to unpause"); // Requires pauser role to unpause.
        _unpause();                                                                      // Calls unpause function.
    }

    /// @param from - address sender.
    /// @param to - address recipient.
    /// @param tokenId - Id of token.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}