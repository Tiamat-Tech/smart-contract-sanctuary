pragma solidity ^0.7.0;
pragma abicoder v2;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @title ZooNft Contract.
/// @notice based on OpenZeppelin's ERC721PresetMinterPauserAutoId.
contract ZooNft is AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIdTracker;                   // Token id tracker.

	mapping(string => uint8) hashes;                            // Records what hash was used.

    using Strings for uint256;

    /// All the tokens are grouped in batches. Batch is basically IPFS folder (DAG)
    /// that stores token JSON metadata and images. It tokenId falls into batch, the
    /// tokenURI = batch.baseURI + "/" + tokenId.
    struct Batch {
        uint256 startTokenId;
        uint256 endTokenId;
        string baseURI;
    }

    Batch[] internal _batches;

	/// @notice Contract constructor.
	/// @notice Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` to the account that deploys the contract.
    /// @notice See {ERC721-tokenURI}.
    /// @param name - name of contract.
    /// @param symbol - symbol of contract.
    /// @param uri - URI of the token that doesnt fall into any batch
    constructor(string memory name, string memory symbol, string memory uri) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setBaseURI(uri);
    }


    /**
     * @dev IPFS address that stores JSON with token attributes
     * Tries to find it by batch first. If token has no batch, returns defaultUri.
     * @param tokenId id of the token
     * @return string with ipfs address to json with token attribute
     * or URI for default token if token doesn`t exist
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_batches.length > 0, "tokenURI: no batches");

        for (uint256 i; i < _batches.length; i++) {
            if (tokenId > _batches[i].endTokenId || tokenId < _batches[i].startTokenId) {
                continue;
            } else {
                return string(abi.encodePacked(_batches[i].baseURI, "/", tokenId.toString(), ".json"));
            }
        }
        return baseURI();
    }

    /**
     * @notice Create the new batch for given token range
     * @param startTokenId index of the first batch token
     * @param endTokenId index of the last batch token
     * @param baseURI ipfs base URI
     * Note: batch ids can change over time and reorder as the result of batch removal
     */
    function addBatch(
        uint256 startTokenId,
        uint256 endTokenId,
        string memory baseURI
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "need DEFAULT_ADMIN_ROLE");
        uint256 _batchesLength = _batches.length;
        require(startTokenId <= endTokenId, "startId must be <= than EndId");
        if (_batchesLength > 0) {
            for (uint256 i; i < _batchesLength; i++) {
                // if both bounds are lower or higher than iter batch
                if (
                    (startTokenId < _batches[i].startTokenId && endTokenId < _batches[i].startTokenId) ||
                    (startTokenId > _batches[i].endTokenId && endTokenId > _batches[i].endTokenId)
                ) {
                    continue;
                } else {
                    revert("batches intersect");
                }
            }
        }
        _batches.push(Batch(startTokenId, endTokenId, baseURI));
    }

    /**
     * @notice Update existing batch by its index
     * @param batchIndex the index of the batch to be changed
     * @param batchStartId index of the first batch token
     * @param batchEndId index of the last batch token
     * @param baseURI ipfs batch URI
     * Note: batches can reorder as the result of batch removal
     */
    function setBatch(
        uint256 batchIndex,
        uint256 batchStartId,
        uint256 batchEndId,
        string memory baseURI
    ) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "need DEFAULT_ADMIN_ROLE");
        uint256 _batchesLength = _batches.length;
        require(_batchesLength > 0, "setBatch: batches is empty");
        require(batchStartId <= batchEndId, "startId must be <= than EndId");

        for (uint256 i; i < _batchesLength; i++) {
            if (i == batchIndex) {
                continue;
            } else {
                // if both bounds are lower or higher than iter batch
                if (
                    (batchStartId < _batches[i].startTokenId && batchEndId < _batches[i].startTokenId) ||
                    (batchStartId > _batches[i].endTokenId && batchEndId > _batches[i].endTokenId)
                ) {
                    continue;
                } else {
                    revert("batches intersect");
                }
            }
        }

        _batches[batchIndex].startTokenId = batchStartId;
        _batches[batchIndex].endTokenId = batchEndId;
        _batches[batchIndex].baseURI = baseURI;
    }

    /**
     * @notice Deletes batch by its id. This reorders the index of the token that was last.
     * @param batchIndex the index of the batch to be deteted
     */
    function deleteBatch(uint256 batchIndex) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "need DEFAULT_ADMIN_ROLE");
        require(_batches.length > batchIndex, "index out of batches length");
        _batches[batchIndex] = _batches[_batches.length - 1];
        _batches.pop();
    }

	/// @notice Creates new Nft token, requires minter role, generate URI from baseURI and hash of metadata.
	/// @param to - address recipient of token.
	/// @param hash - hash of the image.
	/// @param metadata - hash of the metadata of the asset.
    function mint(address to, string memory hash, string memory metadata) public returns (uint256) {
        require(hasRole(MINTER_ROLE, _msgSender()), "must have minter role to mint"); // Requires minter role to mint.

		require((hashes[hash] != 1), "Hash is already used!");  // Requires hash to be non-used before.

		hashes[hash] = 1;                                       // Records that hash became in use.

		uint256 tokenId = _tokenIdTracker.current();            // Calls Id for nft.

        _mint(to, tokenId);                                     // Calls _mint function
        _tokenIdTracker.increment();                            // Increments id.
		_setTokenURI(tokenId, metadata);                        // Matches token uri for token id.

		return tokenId;                                         // Returns id of token.
	}

    /**
     * @dev Mints a specific token (with known id) to the given address
     * @param to the receiver
     * @param mintIndex the tokenId to mint
     */
    function mint(address to, uint256 mintIndex) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "MINTER_ROLE required");
        _safeMint(to, mintIndex);
    }

    /// @param from - address sender.
    /// @param to - address recipient.
    /// @param tokenId - Id of token.
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Set defaultUri
     */
    function setBaseUri(string memory uri) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "need DEFAULT_ADMIN_ROLE");
        _setBaseURI(uri);
    }

}