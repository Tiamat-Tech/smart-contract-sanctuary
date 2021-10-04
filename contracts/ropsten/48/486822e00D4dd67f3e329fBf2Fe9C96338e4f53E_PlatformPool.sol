// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import { PoolTokenFactory } from "./libs/PoolTokenFactory.sol";

contract PlatformPool is Context, AccessControlEnumerable, Pausable {
	/* Here we create an Assess Control slot for the Cent Admin */
	bytes32 public constant ASSETS_ADMIN_ROLE = keccak256("ASSETS_ADMIN_ROLE");
	string public _poolBaseURI;

	/**
	 * @dev dictionary to track the attributes of asset pools on the blockchain
	 * Contract Address has an interface of IERC-20 because they are ERC-20 tokens
	 * that will be distributed, and the uri is bytes32 hash of the name and ID from Cent
	 * Admin Gateway generated off-chain but used to track both chain and onchain records.
	 */
	struct AssetPool {
		PoolTokenFactory _contractAddress;
		string _name;
		string _ticker;
		bytes32 _uri;
		string _templateTag;
	}

	/**
	 * @dev create a mapping of bytes32 xxhash hash of asset pool{uri} to Asset pool
	 * struct so that we can easily retrieve pool props and execute requests
	 */
	mapping(bytes32 => AssetPool) public _pools;
	event AssetPoolCreated(PoolTokenFactory contractAddress, string name, string ticker, bytes32 uri);

	/**
	 * @dev ledger of transactions on pool tokens
	 * map the pool token contract address to transactions
	 */

	struct PoolTransaction {
		uint256 _tokenValueIssued;
		address _recipient;
	}
	mapping(address => PoolTransaction[]) public _ledger;
	event PoolTokenFunded(address tokenAddress, address recipient, uint256 tokenValueIssued);

	constructor(string memory poolBaseURI) {
		_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		_setupRole(ASSETS_ADMIN_ROLE, _msgSender());

		// Set the base URI for Asset pools, use for retriving pool templates and statuses
		_poolBaseURI = poolBaseURI;
	}

	/**
	 * @dev modifier to only allow an admin to perform an action
	 */
	modifier onlyCentAdmin() {
		require(hasRole(ASSETS_ADMIN_ROLE, _msgSender()), "Cent: account not allowed");
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

	function setBaseUriForPools(string memory baseURI) public onlyCentAdmin whenNotPaused {
		_setBaseUriForPools(baseURI);
	}

	/**
	 * @dev Internal function to set the base URI for all token IDs. It is
	 * automatically added as a prefix to the value returned in {tokenURI},
	 * or to the token ID if {tokenURI} is empty.
	 */
	function _setBaseUriForPools(string memory baseURI) internal virtual {
		_poolBaseURI = baseURI;
	}

	function createNewAssetPool(
		string memory name,
		string memory ticker,
		string memory templateTag,
		bytes32 tokenURI
	) public onlyCentAdmin whenNotPaused {
		bytes32 poolTokenUri = tokenURI;
		PoolTokenFactory poolToken = new PoolTokenFactory(name, ticker);

		// store pools to pool token mapping
		AssetPool memory pool = AssetPool(poolToken, name, ticker, poolTokenUri, templateTag);
		_pools[poolTokenUri] = pool;

		// emit event once pool token create
		emit AssetPoolCreated(poolToken, name, ticker, poolTokenUri);
	}

	// function fundPoolWithERCToken() public returns(bool) {}

	/** @dev Fund Pool with native token, in this case ETH, given the hash map of the pool token
	 * Will Take the ETH equivalent and fund the pool with corresponding amount
	 *
	 * AssetPool Struct need to track ETH price per pool or wei equivalent
	 * AssetPool Struct to also track USDC Price or Equivalent and retrieve from external oracle.
	 * _uri is the bytes32 hash of the pool token name and id off-chain
	 */
	function fundPoolWithNativeToken(bytes32 _uri) public payable returns (bool) {
		require(msg.value > 0, "You need to send some ether");

		uint256 tokenValueToIssue = msg.value * 100;
		AssetPool memory pool = _pools[_uri];
		address recipient = msg.sender;
		address tokenAddress = address(pool._contractAddress);
		// uint256 dexBalance = poolToken.balanceOf(address(this));

		// EXTCALL to Mint PoolToken for recipient
		// @TODO use require and run checks interaction to ensure pool token must be funded
		// require(pool._contractAddress.mint(recipient, tokenValueToIssue), "failed to fund pool token");
		pool._contractAddress.mint(recipient, tokenValueToIssue);

		// Store transaction in Ledger
		PoolTransaction memory record = PoolTransaction(tokenValueToIssue, recipient);
		PoolTransaction[] storage transactions = _ledger[tokenAddress];
		transactions.push(record);

		emit PoolTokenFunded(tokenAddress, recipient, tokenValueToIssue);
		return true;
	}

	/** @dev mint token after conditions are met
	 * Internal function can only be called from within contract
	 */

	function _mintPoolTokenToInvestor(
		bytes32 tokenUri,
		uint256 amount,
		address to
	) internal whenNotPaused {
		AssetPool memory pool = _pools[tokenUri];
		pool._contractAddress.mint(to, amount);

		// update ledger balance
		// ledger[]
		emit PoolTokenFunded(address(pool._contractAddress), to, amount);
	}
}