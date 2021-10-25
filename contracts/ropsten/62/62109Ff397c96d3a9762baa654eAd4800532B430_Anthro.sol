// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Anthro is ERC721, Ownable, ERC721Enumerable, ERC721URIStorage {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;
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

    // We need a Admin Control section
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        // Might want to check out using this
        // https://docs.openzeppelin.com/contracts/4.x/api/utils#ERC165Checker

        // Also explore the following warning:
        //    Warning: "this" used in constructor. Note that external functions of a contract cannot be called while it is being constructed.
        supportedInterfaces[this.supportsInterface.selector] = true;
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return supportedInterfaces[interfaceID];

        // Example of adding all the supported interfaces
        // supportedInterfaces[this.is2D.selector ^ this.skinColor.selector] = true;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
    * Mint some Anthro for free
    * Owners only
    */
    function ownerMint(string memory hash, string memory metadata) public onlyOwner {
        // Not sure if this is better than calling TotalSupply
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(newItemId < maxAnthro, "No More Anthro to create!");

        // Which is better to use? This or above using the tokenIDs.current()
        // uint supply = totalSupply();
        // uint256 newItemId = supply + 1;

        // This makes sure we haven't used this Hash before
        require(hashes[hash] != 1, "Already exists with IPFS hash");
        hashes[hash] = 1;

        _tokenOwners.set(newItemId, msg.sender);
        _holderTokens[msg.sender].add(newItemId);

        _safeMint(msg.sender, newItemId);
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

    // ==================================================================
    // ==================================================================
    // ==================================================================

    // We don't use this
    // do we need this
    /*
    * Set provenance once it's calculated
    */
    // function setProvenanceHash(string memory provenanceHash) public onlyOwner {
    //     ANTHRO_PROVENANCE = provenanceHash;
    // }

    // Not sure if we need this
    // bool public saleIsActive = false;
    /*
    * Pause sale if active, make active if paused
    */
    // function flipSaleState() public onlyOwner {
    //     saleIsActive = !saleIsActive;
    // }

    // Not sure if we need this
    // string public ANTHRO_PROVENANCE = "";

    // This actually isn't used right now
    // uint256 public constant anthroPrice = 5000000000000000000; //0.5 ETH

    // We aren't actually using this yet
    // uint public constant maxAnthroPurchase = 1;

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    // function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage){
    //     address owner = ERC721.ownerOf(tokenId); // internal owner
    //     _beforeTokenTransfer(owner, address(0), tokenId);
    //     // Clear approvals
    //     _approve(address(0), tokenId);
    //     // Clear metadata (if any)
    //     if (bytes(_tokenURIs[tokenId]).length != 0) {
    //         delete _tokenURIs[tokenId];
    //     }
    //     _holderTokens[owner].remove(tokenId);
    //     _tokenOwners.remove(tokenId);
    //     emit Transfer(owner, address(0), tokenId);
    // }
}