// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Pausable.sol";

contract OurSongFToken is Context, Ownable, ERC1155Burnable, ERC1155Pausable {
  string private _name;
  string private _symbol;

  constructor(string memory name_, string memory symbol_, string memory uri_, address owner_) public ERC1155(uri_) {
    _name = name_;
    _symbol = symbol_;

    transferOwnership(owner_);
  }

  /**
    * @dev Returns the name of the token.
    */
  function name() public view virtual returns (string memory) {
    return _name;
  }

  /**
    * @dev Returns the symbol of the token, usually a shorter version of the
    * name.
    */
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  function setURI(string memory uri_) public virtual onlyOwner {
    _setURI(uri_);
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
  function mint(address to, uint256 id, uint256 amount, bytes memory data) public virtual onlyOwner {
    _mint(to, id, amount, data);
  }

  /**
    * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
    */
  function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual onlyOwner {
    _mintBatch(to, ids, amounts, data);
  }

  /**
    * @dev Pauses all token transfers.
    *
    * See {ERC1155Pausable} and {Pausable-_pause}.
    *
    * Requirements:
    *
    * - the caller must have the `PAUSER_ROLE`.
    */
  function pause() public virtual onlyOwner {
    _pause();
  }

  /**
    * @dev Unpauses all token transfers.
    *
    * See {ERC1155Pausable} and {Pausable-_unpause}.
    *
    * Requirements:
    *
    * - the caller must have the `PAUSER_ROLE`.
    */
  function unpause() public virtual onlyOwner {
    _unpause();
  }

  function _beforeTokenTransfer(
      address operator,
      address from,
      address to,
      uint256[] memory ids,
      uint256[] memory amounts,
      bytes memory data
  )
    internal virtual override(ERC1155, ERC1155Pausable)
  {
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }
}