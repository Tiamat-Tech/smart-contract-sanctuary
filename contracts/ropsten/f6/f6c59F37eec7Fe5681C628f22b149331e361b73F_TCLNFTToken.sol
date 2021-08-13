// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "./AbstractTCLEntity.sol";
import "./ERC1155.sol";

contract TCLNFTToken is ERC1155, AbstractTCLEntity {
  // Token name
  string private _name;

  // Token symbol
  string private _symbol;

  /* the central instance of content */
  uint256 private _maxTierId;

  /****** NFT SECTION *******/
  /* nft data type enum */
  enum NftDataType {TEXT, IMAGE, AUDIO, VIDEO}

  /* nft content struct */
  struct NftContent {
    NftDataType dataType;
    uint256 timestamp;
    uint256 value;
    string ipfsAddress;
  }

  mapping(uint256 => NftContent) private _tierToNftContent;
  mapping(string => bool) private _ipfsAddressUsed;

  event NewNft(address creator, uint256 contentId, uint256 timestamp, NftDataType dataType, string ipfsAddress);

  modifier validTierId(uint256 tier) {
    require(tier != 0 && tier <= _maxTierId, "TCL : Provided tier is not available.");
    _;
  }

  constructor(string memory name_, string memory symbol_, address adminAddr) 
    ERC1155("")
  {
    _name = name_;
    _symbol = symbol_;
    _admin = adminAddr;
    _maxTierId = 3;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
      return _symbol;
  }

  /***************************************************
    * NFTS (public/ external section)
    ***************************************************/

  /**
    * Mint new content as NFT.
    */
  function createContent(uint tier, string memory ipfsAddress, NftDataType dataType, uint amount) external onlyOwnerOrAdmin {
    require(!_ipfsAddressUsed[ipfsAddress], "TCL: IPFS Address has already been used by this collection.");
    /* mint the NFT */
    NftContent memory content = NftContent({
                                    dataType: dataType,
                                    timestamp: block.timestamp,
                                    value: 0,
                                    ipfsAddress: ipfsAddress
                                });

    _mint(address(this), tier, amount, "");
    _tierToNftContent[tier] = content;
    _ipfsAddressUsed[ipfsAddress] = true;

    emit NewNft(address(this), tier, block.timestamp, dataType, ipfsAddress);
  }

  /* get tier ount and is just amount of content NFTs. */
  function tierCount() external view returns (uint256){
    return _maxTierId;
  }

  /* Get content data of the provided tier */
  function getContent(uint256 tier) external view validTierId(tier) returns (NftDataType, uint256, uint256, string memory) {
    NftContent memory content = _tierToNftContent[tier];
    return (content.dataType, content.timestamp, content.value, content.ipfsAddress);
  }

  /* claim NFT by tier */
  function claim(uint tier) public payable validTierId(tier) {
    require(balanceOf(_msgSender(), tier) < 1, "You already had claimed!");
    require(balanceOf(address(this), tier) > 0, "Out of NFT stock!");
    _safeTransferFrom(address(this), _msgSender(), tier, 1, "");
  }
}