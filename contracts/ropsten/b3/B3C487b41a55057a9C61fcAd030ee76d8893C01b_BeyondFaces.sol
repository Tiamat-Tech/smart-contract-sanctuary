// BeyondFaces.sol
// SPDX-License-Identifier: MIT

/* ]3 [- `/ () |\| |) /= /\ ( [- _\~
*
* An NFT project from JARI.
*  2021 BeyondFaces
*/

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC721Metadata {

  /**
   * @dev Returns the token collection name.
   */
  function name() external view returns (string memory);

  /**
   * @dev Returns the token collection symbol.
   */
  function symbol() external view returns (string memory);

  /**
   * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
   */
  function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
  /**
   * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
   * by `operator` from `from`, this function is called.
   *
   * It must return its Solidity selector to confirm the token transfer.
   * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
   *
   * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
   */
  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
  /**
   * @dev Returns true if this contract implements the interface defined by
   * `interfaceId`. See the corresponding
   * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
   * to learn more about how these ids are created.
   *
   * This function call must use less than 30 000 gas.
   */
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IERC721 is IERC721Metadata, IERC165 {
  /**
   * @dev This emits when ownership of any NFT changes by any mechanism.
   */
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
   */
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

  /**
   * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
   */
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  /**
   * @dev Returns the number of tokens in ``owner``'s account.
   */
  function balanceOf(address owner) external view returns (uint256 balance);

  /**
   * @dev Returns the owner of the `tokenId` token.
   */
  function ownerOf(uint256 tokenId) external view returns (address owner);

  /**
  * @dev Safely transfers `tokenId` token from `from` to `to`.
  */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

  /**
   * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
   * are aware of the ERC721 protocol to prevent tokens from being forever locked.
   * Emits a {Transfer} event.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) external;

  /**
   * @dev Transfers `tokenId` token from `from` to `to`.
   */
  function transferFrom(address from, address to, uint256 tokenId) external;

  /**
   * @dev Gives permission to `to` to transfer `tokenId` token to another account.
   * The approval is cleared when the token is transferred.
   */
  function approve(address to, uint256 tokenId) external;

  /**
 * @dev Approve or remove `operator` as an operator for the caller.
 * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
 */
  function setApprovalForAll(address operator, bool _approved) external;

  /**
   * @dev Returns the account approved for `tokenId` token.
   */
  function getApproved(uint256 tokenId) external view returns (address operator);

  /**
   * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
   * See {setApprovalForAll}
   */
  function isApprovedForAll(address owner, address operator) external view returns (bool);

}



contract BeyondFaces is IERC721, Ownable {
  using Address for address;
  using Strings for uint256;

  address proxyRegistryAddress;

  // Maximum number of Faces that can be minted
  uint256 constant internal TOTAL_FACES = 25;

  // Token Name
  string internal nftName = "BeyondFaces";

  // Token symbol
  string internal nftSymbol = "FACE";

  // Uri path
  string internal ntfBaseUri = "https://api.beyondfaces.io/face/";

  // Start at 1 based index.
  uint256 private _currentTokenId = 0;

  // Mapping from token ID to owner address
  mapping (uint256 => address) private _owners;

  // Mapping owner address to token count
  mapping (address => uint256) private _balances;

  // Mapping from token ID to approved address
  mapping (uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping (address => mapping (address => bool)) private _operatorApprovals;

  // Constructor
  // Name an Symbol are hardcoded into contract
  constructor(address _proxyRegistryAddress) Ownable() {
    proxyRegistryAddress = _proxyRegistryAddress;
  }

  /**
 * @dev increments the value of _currentTokenId
 */
  function _incrementTokenId() private {
    _currentTokenId = _currentTokenId + 1;
  }

  /*
  * Returns the id of the latest minted token
  */
  function currentTokenId() public view returns(uint256){
    return _currentTokenId;
  }

  /*
  * Returns the tokenId by a given Index
  */
  function tokenByIndex(uint256 index) public pure returns (uint256) {
    require(index >= 0 && index < TOTAL_FACES);
    return index + 1;
  }

  /*
  * Returns the total number of tokens
  */
  function totalSupply() public pure returns (uint256) {
    return TOTAL_FACES;
  }


  /**
  * Mints Face
  */
  function mintTo() public onlyOwner {
    _safeMint(owner(),_currentTokenId);
  }

  /**
 * Mints 25 Face
 */
  function autoMint() public onlyOwner {
    require(_currentTokenId >=0 && _currentTokenId < TOTAL_FACES, "ERC721: maximum tokens minted");
  for(uint256 i = _currentTokenId; i < TOTAL_FACES; i++){
      mintTo();
    }
  }

  /**
    * @dev See {IERC165-supportsInterface}.
    */
  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165) returns (bool) {
    return interfaceId == type(IERC721).interfaceId
    || interfaceId == type(IERC721Metadata).interfaceId
    || interfaceId == type(IERC165).interfaceId;
  }


  /**
     * @dev See {IERC721-balanceOf}.
     */
  function balanceOf(address owner) public view virtual override returns (uint256) {
    require(owner != address(0), "ERC721: balance query for the zero address");
    return _balances[owner];
  }

  /**
   * @dev See {IERC721-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    address owner = _owners[tokenId];
    require(owner != address(0), "ERC721: owner query for nonexistent token");
    return owner;
  }

  /**
 * @dev See {IERC721-approve}.
 */
  function approve(address to, uint256 tokenId) public virtual override {
    address owner = ownerOf(tokenId);
    require(to != owner, "ERC721: approval to current owner");
    require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
      "ERC721: approve caller is not owner nor approved for all"
    );
    _approve(to, tokenId);
  }

  /**
   * @dev See {IERC721-getApproved}.
   */
  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    require(_exists(tokenId), "ERC721: approved query for nonexistent token");
    return _tokenApprovals[tokenId];
  }

  /**
   * @dev See {IERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    require(operator != _msgSender(), "ERC721: approve to caller");
    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
   */
  function isApprovedForAll(address owner, address operator) override public view returns (bool)
  {
    // Whitelist OpenSea proxy contract for easy trading.
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(owner)) == operator) {
      return true;
    }
    return _isApprovedForAll(owner, operator);
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(address from, address to, uint256 tokenId) public virtual override {
    //solhint-disable-next-line max-line-length
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
    safeTransferFrom(from, to, tokenId, "");
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
    require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }



  /**
   * @dev See {IERC721Metadata-name}.
   */
  function name() public view virtual override returns (string memory _name) {
    _name = nftName;
  }

  /**
   * @dev See {IERC721Metadata-symbol}.
   */
  function symbol() public view virtual override returns (string memory _symbol) {
    _symbol = nftSymbol;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0
    ? string(abi.encodePacked(baseURI, tokenId.toString()))
    : '';
  }

  /**
 * @dev See {IERC721-isApprovedForAll}.
 * original implementation
 */
  function _isApprovedForAll(address owner, address operator) internal view virtual returns (bool) {
    return _operatorApprovals[owner][operator];
  }


  /**
 * This is used instead of msg.sender as transactions won't be sent by the original token owner, but by OpenSea.
 */
  function msgSender() internal  view  returns (address payable sender)  {
    if (msg.sender == address(this)) {
      bytes memory array = msg.data;
      uint256 index = msg.data.length;
      assembly {
      // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
        sender := and(
        mload(add(array, index)),
        0xffffffffffffffffffffffffffffffffffffffff
        )
      }
    } else {
      sender = payable(msg.sender);
    }
    return sender;
  }


  /**
   * @dev Approve `to` to operate on `tokenId`
   *
   * Emits a {Approval} event.
   */
  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(ownerOf(tokenId), to, tokenId);
  }

  /**
 * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
 * in child contracts.
 */
  function _baseURI() internal view virtual returns (string memory _baseUri) {
    _baseUri = ntfBaseUri;
  }

  /**
 * @dev Hook that is called before any token transfer. This includes minting
 * and burning.
 *
 * Calling conditions:
 *
 * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
 * transferred to `to`.
 * - When `from` is zero, `tokenId` will be minted for `to`.
 * - When `to` is zero, ``from``'s `tokenId` will be burned.
 * - `from` cannot be the zero address.
 * - `to` cannot be the zero address.
 *
 * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
 */
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }


  /**
* @dev Returns whether `tokenId` exists.
*
* Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
*
* Tokens start existing when they are minted (`_mint`),
* and stop existing when they are burned (`_burn`).
*/
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _owners[tokenId] != address(0);
  }

  /**
* @dev Returns whether `spender` is allowed to manage `tokenId`.
*
* Requirements:
*
* - `tokenId` must exist.
*/
  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
    require(_exists(tokenId), "ERC721: operator query for nonexistent token");
    address owner = ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

  /**
 * @dev Safely mints `tokenId` and transfers it to `to`.
 *
 * Requirements:
 *
 * - `tokenId` must not exist.
 * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
 *
 * Emits a {Transfer} event.
 */
  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, "");
  }

  /**
   * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
   * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
   */
  function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
    _mint(to, tokenId);
    require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
  }

  /**
   * @dev Mints `tokenId` and transfers it to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `to` cannot be the zero address.
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), "ERC721: mint to the zero address");
    require(!_exists(tokenId), "ERC721: token already minted");
    require(_currentTokenId >= 0 && _currentTokenId < TOTAL_FACES, "ERC721: maximum tokens minted");

    _beforeTokenTransfer(address(0), to, tokenId);

    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(address(0), to, tokenId);
    _incrementTokenId();
  }

  /**
 * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
 * are aware of the ERC721 protocol to prevent tokens from being forever locked.
 *
 * `_data` is additional data, it has no specified format and it is sent in call to `to`.
 *
 * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
 * implement alternative mechanisms to perform token transfer, such as signature-based.
 *
 * Requirements:
 *
 * - `from` cannot be the zero address.
 * - `to` cannot be the zero address.
 * - `tokenId` token must exist and be owned by `from`.
 * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
 *
 * Emits a {Transfer} event.
 */
  function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
    _transfer(from, to, tokenId);
    require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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
  function _transfer(address from, address to, uint256 tokenId) internal virtual {
    require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
    require(to != address(0), "ERC721: transfer to the zero address");

    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _balances[from] -= 1;
    _balances[to] += 1;
    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);
  }

  /**
* @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
* The call is not executed if the target address is not a contract.
*
* @param from address representing the previous owner of the given token ID
* @param to target address that will receive the tokens
* @param tokenId uint256 ID of the token to be transferred
* @param _data bytes optional data to send along with the call
* @return bool whether the call correctly returned the expected magic value
*/
  function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
  private returns (bool)
  {
    if (to.isContract()) {
      try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
        return retval == IERC721Receiver(to).onERC721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("ERC721: transfer to non ERC721Receiver implementer");
        } else {
          // solhint-disable-next-line no-inline-assembly
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }
}

// Special for Open Sea integration
contract OwnableDelegateProxy {}

contract ProxyRegistry {
  mapping(address => OwnableDelegateProxy) public proxies;
}