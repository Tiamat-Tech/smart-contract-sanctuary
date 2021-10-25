// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import { BurnableAsset } from "./libs/BurnableAsset.sol";

contract PlatformAsset is Context, AccessControlEnumerable, Pausable, BurnableAsset {
	/* Here we create an Assess Control slot for the Cent Admin */
	bytes32 public constant ASSETS_ADMIN_ROLE = keccak256("ASSETS_ADMIN_ROLE");

	struct Asset {
		string _name;
		address _poolTokenAddress;
		uint256 _uri;
	}

	/**
	 * @dev ledger of all Non Fungible assets that are minted on the Cent Platform
	 * mapping is of poolTokenAddress to Asset Metadata
	 */

	mapping(address => Asset[]) public _assets;

	constructor(string memory baseURI) ERC1155(baseURI) {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ASSETS_ADMIN_ROLE, msg.sender);
	}

	/**
	 * @dev modifier to only allow an admin to perform an action
	 */
	modifier onlyCentAdmin() {
		require(hasRole(ASSETS_ADMIN_ROLE, msg.sender), "Cent: account not allowed");
		_;
	}

	/**
	 * @dev Pauses all token transfers.
	 * See {Pausable-_pause}.
	 *
	 * Requirements:
	 * - the caller must have the `ASSETS_ADMIN_ROLE`.
	 */
	function pause() public virtual onlyCentAdmin {
		_pause();
	}

	/**
	 * @dev Unpauses all token transfers.
	 * See {Pausable-_unpause}.
	 *
	 * Requirements:
	 * - the caller must have the `ASSETS_ADMIN_ROLE`.
	 */
	function unpause() public virtual onlyCentAdmin {
		_unpause();
	}

	function addUserToAdminRole(address user) public onlyCentAdmin {
		grantRole(ASSETS_ADMIN_ROLE, user);
	}

	/** @dev use to set the base URI for Real world Asset Instance
	 * on-chain once they've been purchased on delivered
	 */
	function setBaseUriForAssets(string memory newuri) public onlyCentAdmin {
		super._setURI(newuri);
	}

	/**
	 * @dev Creates `amount` new tokens for `to`, of token type `id`.
	 *
	 * See {ERC1155-_mint}.
	 *
	 * Requirements:
	 *
	 * - the caller must have the `MINTER_ROLE`.
	 */
	function mintNewAsset(
		address poolTokenAddress,
		uint256 id,
		uint256 amount,
		string memory name,
		bytes memory data
	) public virtual onlyCentAdmin {
		Asset memory asset = Asset(name, poolTokenAddress, id);

		// Store mapping of all assets in asset pool
		_assets[poolTokenAddress].push(asset);

		_mint(poolTokenAddress, id, amount, data);
	}

	/**
	 * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
	 */
	function batchMintAssets(
		address to,
		uint256[] memory ids,
		uint256[] memory amounts,
		bytes memory data
	) public virtual onlyCentAdmin {
		_mintBatch(to, ids, amounts, data);
	}

	/**
	 * @dev See {ERC1155-_beforeTokenTransfer}.
	 *
	 * Requirements:
	 * - the contract must not be paused.
	 * By running this hook, we can run all the checks that are required before minting any asset instance
	 * Especially in a case where we want to make sure that the minting actions are not
	 * paused or put on hold before proceeding
	 */
	function _beforeTokenTransfer(
		address operator,
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts,
		bytes memory data
	) internal virtual override(ERC1155) {
		// Run checks for the hook before calling Inherited Hook method
		require(!paused(), "Cent: token actions paused");
		super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
	}

	/**
	 * @dev See {IERC165-supportsInterface}.
	 * Contracts derived from ERC-1155 must override the supportsInterface
	 */
	function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlEnumerable, ERC1155) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}