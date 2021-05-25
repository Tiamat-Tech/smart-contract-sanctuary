// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @dev IMX Mintable interface, enables Layer 2 minting in IMX,
///      see https://docs.x.immutable.com/docs/minting-assets-1
interface Mintable {
  /// @dev Mints an NFT
  /// @param to address to mint NFT to
  /// @param amount ID of the NFT to mint
  /// @param mintingBlob [optional] data structure stored alongside with NFT
  function mintFor(address to, uint256 amount, bytes memory mintingBlob) external;
}

/**
 * @title NFT Mock
 *
 * @notice ERC721 smart contract for IMX testnet tests
 *
 * @author Basil Gorin
 */
contract NFTMock is ERC721Enumerable, Mintable, AccessControl {
  /// @dev Just store blobs as is, without parsing into any meaningful structures
  mapping(uint256 => bytes) public mintingBlobs;

  /**
   * @notice Token creator is responsible for creating (minting)
   *      tokens to an arbitrary address
   * @dev Role ROLE_TOKEN_CREATOR allows minting tokens
   *      (executing `mint` function)
   */
  bytes32 public constant ROLE_TOKEN_CREATOR = keccak256("ROLE_TOKEN_CREATOR");

  /**
   * @notice URI manager is responsible for managing baseURI
   *      part of the tokenURI IERC721Metadata interface
   * @dev Role ROLE_URI_MANAGER allows updating the base URI
   *      (executing `setBaseURI` function)
   */
  bytes32 public constant ROLE_URI_MANAGER = keccak256("ROLE_URI_MANAGER");

  /// @dev Base URI for NFT metadata URI construction
  string private __baseURI = "https://illuvium.io/nft_mock";

  /**
   * @dev Fired in setBaseURI()
   *
   * @param _by an address which executed update
   * @param oldVal old _baseURI value
   * @param newVal new _baseURI value
   */
  event BaseURIUpdated(address indexed _by, string oldVal, string newVal);

  /// @dev Creates/deploys new NFT Mock with name/symbol predefined
  constructor() ERC721("IMX Test NFT", "ITN") {
    // Grant the contract deployer the default admin role:
    // it will be able to grant and revoke any roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @inheritdoc Mintable
  function mintFor(address to, uint256 amount, bytes memory mintingBlob) public override {
    // only IMX is allowed to use this interface
    require(msg.sender == 0x5FDCCA53617f4d2b9134B29090C87D01058e27e9, "access denied");

    // mint the token - delegate to Zeppelin `mint`
    _mint(to, amount);

    // save the metadata - `mintingBlob`
    mintingBlobs[amount] = mintingBlob;
  }

  /// @dev Mints an NFT
  /// @param _to address to mint NFT to
  /// @param _tokenId ID of the NFT to mint
  function mint(address _to, uint256 _tokenId) public {
    // verify the call is done by the token creator
    require(hasRole(ROLE_TOKEN_CREATOR, msg.sender), "access denied");

    // mint the token - delegate to Zeppelin `mint`
    _mint(_to, _tokenId);
  }

  /// @dev Resolves multiple inheritance conflict ERC721Enumerable/AccessControl ERC165
  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, AccessControl) returns (bool) {
    // merge 2 conflicting implementations and return
    return ERC721Enumerable.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
  }

  /**
   * @dev Restricted access function which updates iNFT _baseURI used to construct
   *      IERC721Metadata.tokenURI
   *
   * @param baseURI new _baseURI to set
   */
  function setBaseURI(string memory baseURI) public {
    // verify the access permission
    require(hasRole(ROLE_URI_MANAGER, msg.sender), "access denied");

    // emit an event first - to log both old and new values
    emit BaseURIUpdated(msg.sender, __baseURI, baseURI);

    // and update base URI
    __baseURI = baseURI;
  }

  /**
   * @inheritdoc ERC721
   */
  function _baseURI() internal view override returns (string memory) {
    // read _baseURI from storage into memory and return
    return __baseURI;
  }
}