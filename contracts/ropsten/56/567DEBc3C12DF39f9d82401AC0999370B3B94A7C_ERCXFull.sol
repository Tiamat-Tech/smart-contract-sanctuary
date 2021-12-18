//SPDX-License-Identifier: un-licensed
pragma solidity ^0.8.0;

import './ERCX.sol';
import './ERCXEnumerable.sol';
import '../Interface/IERCXMetadata.sol';


contract ERCXFull is ERCXEnumerable, IERCXMetadata {
    // item name
  string internal _name;

  // item symbol
  string internal _symbol;

  // Base URI
  string private _baseURI;

  // token ID
  uint256 counter;
  address owner;
  
  // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

  // Optional mapping for item URIs
  mapping(uint256 => string) private _itemURIs;

  /**
   * @dev Constructor function
   */
      constructor(string memory name_, string memory symbol_) {
          _name = name_;
          _symbol = symbol_;
          owner = msg.sender;

          counter = 0;
      }
      
        /**
   * @dev Gets the item name
   * @return string representing the item name
   */
  function name() external override view returns (string memory) { 
    return _name;
  }

  /**
   * @dev Gets the item symbol
   * @return string representing the item symbol
   */
  function symbol() external override view returns (string memory) {
    return _symbol;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  
  function mint() external onlyOwner{
        require(msg.sender != address(0), "ERC721: mint to the zero address");
        
        super._mint(msg.sender, counter);
        _owners[counter] = msg.sender;
        counter++;
    }
  
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
   * @dev Returns an URI for a given item ID
   * Throws if the item ID does not exist. May return an empty string.
   * @param itemId uint256 ID of the item to query
   */
  function itemURI(uint256 itemId) public override view returns (string memory) {
    require(
      _exists(itemId,1),
      "URI query for nonexistent item");

    string memory _itemURI = _itemURIs[itemId];

    // Even if there is a base URI, it is only appended to non-empty item-specific URIs
    if (bytes(_itemURI).length == 0) {
        return "";
    } else {
        // abi.encodePacked is being used to concatenate strings
        return string(abi.encodePacked(_baseURI, _itemURI));
    }

  }

  /**
  * @dev Returns the base URI set via {_setBaseURI}. This will be
  * automatically added as a preffix in {itemURI} to each item's URI, when
  * they are non-empty.
  */
  function baseURI() external view returns (string memory) {
      return _baseURI;
  }

  function count() external view returns (uint256) {
    return counter;
  }

  /**
   * @dev Internal function to set the item URI for a given item
   * Reverts if the item ID does not exist
   * @param itemId uint256 ID of the item to set its URI
   * @param uri string URI to assign
   */
  function _setItemURI(uint256 itemId, string memory uri) internal {
    require(_exists(itemId,1));
    _itemURIs[itemId] = uri;
  }

  /**
    * @dev Internal function to set the base URI for all item IDs. It is
    * automatically added as a prefix to the value returned in {itemURI}.
    *
    * Available since v2.5.0.
    */
  function _setBaseURI(string memory baseUri) external {
      _baseURI = baseUri;
  }
  
  function setLienOnMortgage(address owner, address buyer, uint256 id) internal {
      approveLien(owner, id);
      setLien(id);
      safeTransferUser(owner, buyer, id);
  }
}