pragma solidity ^0.7.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";

/// @title Nft Contract with minter and pauser roles.
/// @notice based on OpenZeppelin's ERC721PresetMinterPauserAutoId.
contract Nft is Context, AccessControl, ERC721Burnable, ERC721Pausable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    Counters.Counter private _tokenIdTracker;

	mapping(string => uint8) hashes;							// Records what hash was used.

	/// @notice Contract contstructor.
	/// @notice Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `PAUSER_ROLE` to the account that deploys the contract.
    /// @notice See {ERC721-tokenURI}.
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
    function mint(address to, string memory hash, string memory metadata) public returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");

		require((hashes[hash] != 1), "Hash is already used!");

		hashes[hash] = 1;										// Records that hash became in use.

		uint256 tokenId = _tokenIdTracker.current();			// Calls Id for nft.
		
        _mint(to, tokenId);										// Calls _mint function
        _tokenIdTracker.increment();							// Increments id.
		_setTokenURI(tokenId, metadata);						// Matches token uri for token id.

		return tokenId;
	}


	/// @notice Pauses all token transfers.
   	/// @notice See {ERC721Pausable} and {Pausable-_pause}.
    /// @notice The caller must have the `PAUSER_ROLE`.
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to pause");
        _pause();
    }

    /// @notice Unpauses all token transfers.
    /// @notice See {ERC721Pausable} and {Pausable-_unpause}.
    /// @notice The caller must have the `PAUSER_ROLE`.
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have pauser role to unpause");
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}