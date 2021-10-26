// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";

contract Anthro is ERC721, Ownable, ERC721Enumerable, ERC721URIStorage, IERC2981, AccessControl {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes4 => bool) internal supportedInterfaces;

    Counters.Counter private _tokenIds;

    // Store Hashes for IPFS
    mapping(string => uint8) private hashes;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Should we let it be flexible???
    // We are we using this?
    uint256 public maxAnthro = 100;

    string public _openseaURI = "https://anthro.mypinata.cloud/ipfs/QmazjjExs9U4XZZDd6Shhs8t6fuNVz2Ze3uNjMuUf3cB38";

    address public _artist;

    constructor(string memory name, string memory symbol, address artist) ERC721(name, symbol) {
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
      _artist = artist;
      _setupRole(ADMIN_ROLE, artist);

      // const members = [];
      // for (let i = 0; i < minterCount; ++i) {
          // members.push(await myToken.getRoleMember(MINTER_ROLE, i));
      // }

      // https://docs.openzeppelin.com/contracts/4.x/api/utils#ERC165Checker
      // Also explore the following warning:
      //    Warning: "this" used in constructor. Note that external functions
      //    of a contract cannot be called while it is being constructed.
      supportedInterfaces[this.supportsInterface.selector] = true;
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override(
      AccessControl, IERC165, ERC721, ERC721Enumerable) returns (bool) {
        return supportedInterfaces[interfaceID];

        // Example of adding all the supported interfaces
        // supportedInterfaces[this.is2D.selector ^ this.skinColor.selector] = true;
    }

    function updateOpenseaMetadata(string memory newURI) public onlyOwner {
      _openseaURI = newURI;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function adminMint(string memory hash, string memory metadata) public onlyRole(ADMIN_ROLE) {
        _mint(msg.sender, hash, metadata);
    }

    function ownerMint(string memory hash, string memory metadata) public onlyOwner {
        _mint(msg.sender, hash, metadata);
    }

    function _mint(address minter, string memory hash, string memory metadata) public onlyOwner {
    // function _mint(address minter, string memory hash, string memory metadata) internal onlyOwner {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(newItemId < maxAnthro, "No More Anthro to create!");

        // This makes sure we haven't used this Hash before
        require(hashes[hash] != 1, "Already exists with IPFS hash");
        hashes[hash] = 1;

        _tokenOwners.set(newItemId, minter);
        _holderTokens[minter].add(newItemId);

        // Whose allowed to safeMint???
        // Just Owners
        _safeMint(minter, newItemId);
        _setTokenURI(newItemId, metadata);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyOwner {
      _transfer(from, to, tokenId);

      // This way we use the transformFrom and our own shit
      // super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    // We aren't using this _baseURIextended
    string private _baseURIextended;
    function _baseURI() internal view virtual override returns (string memory) {
        // Not sure if I should make this editable?
        // That does allow changing the collection
        // We could also update later
        // Not sure
        // return _baseURIextended;
        return "https://anthro.mypinata.cloud/ipfs/";
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    // Not sure if we want a burn function
    // but need to implement it for URI storage
    // We could restrict this to only owner
    // Maybe not users
    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage){
        // Not sure about the proper no-op
        require(true == false, string(abi.encodePacked("You can't burn: ", tokenId.toString())));
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual override {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }

    function contractURI() public view returns (string memory) {
        return _openseaURI;
    }

    // =======================
    // === Royalities Info ===
    // =======================

    // TODO: So we need to finish this function!!!
    //
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override(IERC2981) returns (
        address receiver,
        uint256 royaltyAmount
    ) {
      royaltyAmount = 1000; // This is 10%

      return (_artist, royaltyAmount);
      // return (_artist, royaltyAmount);
    }

}