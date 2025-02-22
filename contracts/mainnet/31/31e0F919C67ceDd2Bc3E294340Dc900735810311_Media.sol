// SPDX-License-Identifier: GPL-3.0
// Forked from https://github.com/ourzora/core @ 450cd154bfbb70f62e94050cc3f1560d58e0506a

pragma solidity >=0.8.4;
pragma experimental ABIEncoderV2;

import { ERC721Burnable } from './ERC721Burnable.sol';
import { ERC721 } from './ERC721.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { Counters } from '@openzeppelin/contracts/utils/Counters.sol';
import { SafeMath } from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import { Math } from '@openzeppelin/contracts/utils/math/Math.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { ReentrancyGuard } from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Decimal } from './Decimal.sol';
import { IMedia } from './interfaces/IMedia.sol';
import { IMarket } from './interfaces/IMarket.sol';
import { IDrop } from './interfaces/IDrop.sol';
import { ILux } from './interfaces/ILux.sol';
import './interfaces/IMedia.sol';

import './console.sol';

/**
 * @title A media value system, with perpetual equity to creators
 * @notice This contract provides an interface to mint media with a market
 * owned by the creator.
 */
contract Media is IMedia, ERC721Burnable, ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.UintSet;

  /* *******
   * Globals
   * *******
   */

  // Address for the market
  address public marketContract;

  // Address for the app
  address public appContract;

  // Mapping from token to previous owner of the token
  mapping(uint256 => address) public previousTokenOwners;

  // Mapping from token id to creator address
  mapping(uint256 => address) public tokenCreators;

  // Mapping from creator address to their (enumerable) set of created tokens
  mapping(address => EnumerableSet.UintSet) private _creatorTokens;

  // Mapping from token id to sha256 hash of content
  mapping(uint256 => bytes32) public tokenContentHashes;

  // Mapping from token id to sha256 hash of metadata
  mapping(uint256 => bytes32) public tokenMetadataHashes;

  // Mapping from token id to metadataURI
  mapping(uint256 => string) private _tokenMetadataURIs;

  // Mapping from contentHash to bool
  mapping(bytes32 => bool) private _contentHashes;

  //keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
  bytes32 public constant PERMIT_TYPEHASH = 0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

  //keccak256("MintWithSig(bytes32 contentHash,bytes32 metadataHash,uint256 creatorShare,uint256 nonce,uint256 deadline)");
  bytes32 public constant MINT_WITH_SIG_TYPEHASH = 0x2952e482b8e2b192305f87374d7af45dc2eafafe4f50d26a0c02e90f2fdbe14b;

  // Mapping from address to token id to permit nonce
  mapping(address => mapping(uint256 => uint256)) public permitNonces;

  // Mapping from address to mint with sig nonce
  mapping(address => uint256) public mintWithSigNonces;

  /*
   *     bytes4(keccak256('name()')) == 0x06fdde03
   *     bytes4(keccak256('symbol()')) == 0x95d89b41
   *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
   *     bytes4(keccak256('tokenMetadataURI(uint256)')) == 0x157c3df9
   *
   *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd ^ 0x157c3df9 == 0x4e222e66
   */
  bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x4e222e66;

  Counters.Counter private _tokenIdTracker;

  /* *********
   * Modifiers
   * *********
   */

  /**
   * @notice Require that the token has not been burned and has been minted
   */
  modifier onlyExistingToken(uint256 tokenId) {
    require(_exists(tokenId), 'Media: nonexistent token');
    _;
  }

  /**
   * @notice Require that the token has had a content hash set
   */
  modifier onlyTokenWithContentHash(uint256 tokenId) {
    require(tokenContentHashes[tokenId] != 0, 'Media: token does not have hash of created content');
    _;
  }

  /**
   * @notice Require that the token has had a metadata hash set
   */
  modifier onlyTokenWithMetadataHash(uint256 tokenId) {
    require(tokenMetadataHashes[tokenId] != 0, 'Media: token does not have hash of its metadata');
    _;
  }

  /**
   * @notice Ensure that the provided spender is the approved or the owner of
   * the media for the specified tokenId
   */
  modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
    require(_isApprovedOrOwner(spender, tokenId), 'Media: Only approved or owner');
    _;
  }

  /**
   * @notice Ensure the token has been created (even if it has been burned)
   */
  modifier onlyTokenCreated(uint256 tokenId) {
    require(_tokenIdTracker.current() > tokenId, 'Media: token with that id does not exist');
    _;
  }

  /**
   * @notice Ensure that the provided URI is not empty
   */
  modifier onlyValidURI(string memory uri) {
    require(bytes(uri).length != 0, 'Media: specified uri must be non-empty');
    _;
  }

  /**
   * @notice require that the msg.sender is the configured app, market or contract owner
   */
  modifier onlyAuthorizedCaller() {
    require(appContract == msg.sender || marketContract == msg.sender || owner() == msg.sender, 'Media: Only app contract, market contract or owner');
    _;
  }

  /**
   * @notice On deployment, set the market contract address and register the
   * ERC721 metadata interface
   */
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _registerInterface(_INTERFACE_ID_ERC721_METADATA);
    _tokenIdTracker.increment(); // start at 1
  }

  /**
   * @notice Sets the market contract address. This address is the only permitted address that
   * can call the mutable functions.
   */
  function configure(address appContractAddr, address marketContractAddr) external onlyOwner {
    require(appContractAddr != address(0), 'Media: cannot set app contract as zero address');
    appContract = appContractAddr;
    require(marketContractAddr != address(0), 'Media: cannot set market contract as zero address');
    marketContract = marketContractAddr;
  }

  /* **************
   * View Functions
   * **************
   */

  /**
   * @notice return the URI for a particular piece of media with the specified tokenId
   * @dev This function is an override of the base OZ implementation because we
   * will return the tokenURI even if the media has been burned. In addition, this
   * protocol does not support a base URI, so relevant conditionals are removed.
   * @return the URI for a token
   */
  function tokenURI(uint256 tokenId) public view override onlyTokenCreated(tokenId) returns (string memory) {
    string memory _tokenURI = _tokenURIs[tokenId];

    return _tokenURI;
  }

  /**
   * @notice Return the metadata URI for a piece of media given the token URI
   * @return the metadata URI for the token
   */
  function tokenMetadataURI(uint256 tokenId) external view override onlyTokenCreated(tokenId) returns (string memory) {
    return _tokenMetadataURIs[tokenId];
  }

  /* ****************
   * Public Functions
   * ****************
   */

  /**
   * @notice see IMedia
   */
  function mint(MediaData memory data, IMarket.BidShares memory bidShares) public override nonReentrant onlyAuthorizedCaller {
    _mintForCreator(msg.sender, data, bidShares);
  }

  /**
   * @notice see IMedia
   */
  function mintWithSig(
    address creator,
    MediaData memory data,
    IMarket.BidShares memory bidShares,
    EIP712Signature memory sig
  ) public override nonReentrant onlyAuthorizedCaller {
    require(sig.deadline == 0 || sig.deadline >= block.timestamp, 'Media: mintWithSig expired');

    bytes32 domainSeparator = _calculateDomainSeparator();

    bytes32 digest = keccak256(
      abi.encodePacked(
        '\x19\x01',
        domainSeparator,
        keccak256(abi.encode(MINT_WITH_SIG_TYPEHASH, data.contentHash, data.metadataHash, bidShares.creator.value, mintWithSigNonces[creator]++, sig.deadline))
      )
    );

    address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

    require(recoveredAddress != address(0) && creator == recoveredAddress, 'Media: Signature invalid');

    _mintForCreator(recoveredAddress, data, bidShares);
  }

  /**
   * @notice see IMedia
   */
  function getRecentToken(address creator) public view returns (uint256) {
    uint256 length = EnumerableSet.length(_creatorTokens[creator]) - 1;

    return EnumerableSet.at(_creatorTokens[creator], length);
  }

  /**
   * @notice see IMedia
   */
  function auctionTransfer(uint256 tokenId, address recipient) external override onlyAuthorizedCaller {
    previousTokenOwners[tokenId] = ownerOf(tokenId);
    _safeTransfer(ownerOf(tokenId), recipient, tokenId, '');
  }

  /**
   * @notice see IMedia
   */
  function setAsk(uint256 tokenId, IMarket.Ask memory ask) public override nonReentrant onlyApprovedOrOwner(msg.sender, tokenId) {
    IMarket(marketContract).setAsk(tokenId, ask);
  }

  /**
   * @notice see IMedia
   */
  function setAskFromApp(uint256 tokenId, IMarket.Ask memory ask) public override nonReentrant onlyExistingToken(tokenId) onlyAuthorizedCaller {
    IMarket(marketContract).setAsk(tokenId, ask);
  }

  /**
   * @notice see IMedia
   */
  function removeAsk(uint256 tokenId) external override nonReentrant onlyApprovedOrOwner(msg.sender, tokenId) {
    IMarket(marketContract).removeAsk(tokenId);
  }

  /**
   * @notice see IMedia
   */
  function setBid(uint256 tokenId, IMarket.Bid memory bid) public override nonReentrant onlyExistingToken(tokenId) {
    require(msg.sender == bid.bidder, 'Market: Bidder must be msg sender');
    IMarket(marketContract).setBid(tokenId, bid, msg.sender);
  }

  /**
   * Custom version of setBid where App must be onlyApprovedOrOwner
   * @notice see IMedia
   */
  function setBidFromApp(uint256 tokenId, IMarket.Bid memory bid, address sender) external override nonReentrant onlyExistingToken(tokenId) onlyAuthorizedCaller {
    require(sender == bid.bidder, 'Market: Bidder must be msg sender');
    IMarket(marketContract).setBid(tokenId, bid, sender);
  }

  /**
   * Custom version of setBid where App must be onlyApprovedOrOwner
   * @notice see IMedia
   */
  function setLazyBidFromApp(uint256 dropId, IDrop.TokenType memory tokenType, IMarket.Bid memory bid, address sender) external override nonReentrant onlyAuthorizedCaller {
    require(sender == bid.bidder, 'Market: Bidder must be msg sender');
    IMarket(marketContract).setLazyBidFromApp(dropId, tokenType, bid, sender);
  }

  /**
   * @notice see IMedia
   */
  function removeBid(uint256 tokenId) external override nonReentrant onlyTokenCreated(tokenId) {
    IMarket(marketContract).removeBid(tokenId, msg.sender);
  }

  /**
   * @notice see IMedia
   */
  function removeBidFromApp(uint256 tokenId, address sender) external override nonReentrant onlyTokenCreated(tokenId) onlyAuthorizedCaller {
    IMarket(marketContract).removeBid(tokenId, sender);
  }

  /**
   * @notice see IMedia
   */
  function removeLazyBidFromApp(uint256 dropId, string memory name, address sender) external override nonReentrant onlyAuthorizedCaller {
    IMarket(marketContract).removeLazyBidFromApp(dropId, name, sender);
  }

  /**
   * @notice see IMedia
   */
  function acceptBid(uint256 tokenId, IMarket.Bid memory bid) public override nonReentrant onlyApprovedOrOwner(msg.sender, tokenId) {
    IMarket(marketContract).acceptBid(tokenId, bid);
  }
  
  /**
   * @notice see IMedia
   */
  function acceptBidFromApp(uint256 tokenId, IMarket.Bid memory bid, address sender) external override nonReentrant onlyApprovedOrOwner(sender, tokenId) onlyAuthorizedCaller {
    IMarket(marketContract).acceptBid(tokenId, bid);
  }

  /**
   * @notice see IMedia
   */
  function acceptLazyBidFromApp(uint256 dropId, IDrop.TokenType memory tokenType, ILux.Token memory token, IMarket.Bid memory bid) external override nonReentrant onlyAuthorizedCaller {
    IMarket(marketContract).acceptLazyBidFromApp(dropId, tokenType, token, bid);
  }

  /**
   * @notice Burn a token.
   * @dev Only callable if the media owner is also the creator.
   */
  function burn(uint256 tokenId) public override nonReentrant onlyExistingToken(tokenId) onlyApprovedOrOwner(msg.sender, tokenId) {
    address owner = ownerOf(tokenId);

    require(tokenCreators[tokenId] == owner, 'Media: owner is not creator of media');

    _burn(tokenId);
  }

  /**
   * @notice Revoke the approvals for a token. The provided `approve` function is not sufficient
   * for this protocol, as it does not allow an approved address to revoke it's own approval.
   * In instances where a 3rd party is interacting on a user's behalf via `permit`, they should
   * revoke their approval once their task is complete as a best practice.
   */
  function revokeApproval(uint256 tokenId) external override nonReentrant {
    require(msg.sender == getApproved(tokenId), 'Media: caller not approved address');
    _approve(address(0), tokenId);
  }

  /**
   * @notice see IMedia
   * @dev only callable by approved or owner
   */
  function updateTokenURI(uint256 tokenId, string calldata _tokenURI)
    external
    override
    nonReentrant
    onlyApprovedOrOwner(msg.sender, tokenId)
    onlyTokenWithContentHash(tokenId)
    onlyValidURI(_tokenURI)
  {
    _setTokenURI(tokenId, _tokenURI);
    emit TokenURIUpdated(tokenId, msg.sender, _tokenURI);
  }

  /**
   * @notice see IMedia
   * @dev only callable by approved or owner
   */
  function updateTokenMetadataURI(uint256 tokenId, string calldata metadataURI)
    external
    override
    nonReentrant
    onlyApprovedOrOwner(msg.sender, tokenId)
    onlyTokenWithMetadataHash(tokenId)
    onlyValidURI(metadataURI)
  {
    _setTokenMetadataURI(tokenId, metadataURI);
    emit TokenMetadataURIUpdated(tokenId, msg.sender, metadataURI);
  }

  /**
   * @notice See IMedia
   * @dev This method is loosely based on the permit for ERC-20 tokens in  EIP-2612, but modified
   * for ERC-721.
   */
  function permit(
    address spender,
    uint256 tokenId,
    EIP712Signature memory sig
  ) public override nonReentrant onlyExistingToken(tokenId) {
    require(sig.deadline == 0 || sig.deadline >= block.timestamp, 'Media: Permit expired');
    require(spender != address(0), 'Media: spender cannot be 0x0');
    bytes32 domainSeparator = _calculateDomainSeparator();

    bytes32 digest = keccak256(
      abi.encodePacked('\x19\x01', domainSeparator, keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, permitNonces[ownerOf(tokenId)][tokenId]++, sig.deadline)))
    );

    address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

    require(recoveredAddress != address(0) && ownerOf(tokenId) == recoveredAddress, 'Media: Signature invalid');

    _approve(spender, tokenId);
  }

  /* *****************
   * Private Functions
   * *****************
   */

  /**
   * @notice Creates a new token for `creator`. Its token ID will be automatically
   * assigned (and available on the emitted {IERC721-Transfer} event), and the token
   * URI autogenerated based on the base URI passed at construction.
   *
   * See {ERC721-_safeMint}.
   *
   * On mint, also set the sha256 hashes of the content and its metadata for integrity
   * checks, along with the initial URIs to point to the content and metadata. Attribute
   * the token ID to the creator, mark the content hash as used, and set the bid shares for
   * the media's market.
   *
   * Note that although the content hash must be unique for future mints to prevent duplicate media,
   * metadata has no such requirement.
   */
  function _mintForCreator(
    address creator,
    MediaData memory data,
    IMarket.BidShares memory bidShares
  ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {
    require(data.contentHash != 0, 'Media: content hash must be non-zero');
    // require(_contentHashes[data.contentHash] == false, 'Media: a token has already been created with this content hash');
    require(data.metadataHash != 0, 'Media: metadata hash must be non-zero');

    uint256 tokenId = _tokenIdTracker.current();

    _safeMint(creator, tokenId);
    _tokenIdTracker.increment();
    _setTokenContentHash(tokenId, data.contentHash);
    _setTokenMetadataHash(tokenId, data.metadataHash);
    _setTokenMetadataURI(tokenId, data.metadataURI);
    _setTokenURI(tokenId, data.tokenURI);
    _creatorTokens[creator].add(tokenId);
    _contentHashes[data.contentHash] = true;

    tokenCreators[tokenId] = creator;
    previousTokenOwners[tokenId] = creator;
    IMarket(marketContract).setBidShares(tokenId, bidShares);
  }

  function _setTokenContentHash(uint256 tokenId, bytes32 contentHash) internal virtual onlyExistingToken(tokenId) {
    tokenContentHashes[tokenId] = contentHash;
  }

  function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash) internal virtual onlyExistingToken(tokenId) {
    tokenMetadataHashes[tokenId] = metadataHash;
  }

  function _setTokenMetadataURI(uint256 tokenId, string memory metadataURI) internal virtual onlyExistingToken(tokenId) {
    _tokenMetadataURIs[tokenId] = metadataURI;
  }

  /**
   * @notice Destroys `tokenId`.
   * @dev We modify the OZ _burn implementation to
   * maintain metadata and to remove the
   * previous token owner from the piece
   */
  function _burn(uint256 tokenId) internal override {
    string memory _tokenURI = _tokenURIs[tokenId];

    super._burn(tokenId);

    if (bytes(_tokenURI).length != 0) {
      _tokenURIs[tokenId] = _tokenURI;
    }

    delete previousTokenOwners[tokenId];
  }

  /**
   * @notice transfer a token and remove the ask for it.
   */
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override {
    IMarket(marketContract).removeAsk(tokenId);

    super._transfer(from, to, tokenId);
  }

  /**
   * @dev Calculates EIP712 DOMAIN_SEPARATOR based on the current contract and chain ID.
   */
  function _calculateDomainSeparator() internal view returns (bytes32) {
    uint256 chainID;
    /* solium-disable-next-line */
    assembly {
      chainID := chainid()
    }

    return
      keccak256(
        abi.encode(
          keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
          keccak256(bytes('LUX')),
          keccak256(bytes('1')),
          chainID,
          address(this)
        )
      );
  }

  function _hashToken(address owner, ILux.Token memory token) private view returns (ILux.Token memory) {
    console.log('_hashToken', token.data.tokenURI, token.data.metadataURI);
    token.data.contentHash = keccak256(abi.encodePacked(token.data.tokenURI, block.number, owner));
    token.data.metadataHash = keccak256(abi.encodePacked(token.data.metadataURI, block.number, owner));
    return token;
  }

  function mintToken(address owner, ILux.Token memory token) external override onlyAuthorizedCaller returns (ILux.Token memory) {
    console.log('mintToken', owner, token.name, token.data.tokenURI);
    token = _hashToken(owner, token);
    _mintForCreator(owner, token.data, token.bidShares);
    uint256 id = getRecentToken(owner);
    token.id = id;
    return token;
  }

  function burnToken(address owner, uint256 tokenID) external override nonReentrant onlyExistingToken(tokenID) onlyApprovedOrOwner(owner, tokenID) {
    _burn(tokenID);
  }

  /**
   * @notice Helper to check that token has not been burned or minted
   */
  function tokenExists(uint256 tokenID) public view override returns (bool) {
    return _exists(tokenID);
  }

  function tokenCreator(uint256 tokenID) public view override returns (address) {
    return tokenCreators[tokenID];
  }

  function previousTokenOwner(uint256 tokenID) public view override returns (address) {
    return previousTokenOwners[tokenID];
  }
}