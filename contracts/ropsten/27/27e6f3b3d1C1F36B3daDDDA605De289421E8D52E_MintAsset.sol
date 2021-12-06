//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./NFT.sol";

contract MintAsset is IERC1155Receiver{
  event Deposit(
    address indexed _nftAddress,
    address indexed _from,
    uint256 indexed _nftID
  );

  event Withdraw(
    address indexed _nftAddress,
    address indexed _from,
    uint256 indexed _nftID
  );

  mapping(address => NFT) public nfts;

  address public immutable owner;

  constructor() {
    owner = msg.sender;
  }

  function _addNFT(address _existingNFt) external onlyOwner  returns(NFT){
     nfts[_existingNFt] = new NFT("");
     return  nfts[_existingNFt];
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner can do this action");
    _;
  }

  function _exists(uint256 tokenId, address nft)
    internal
    view
    virtual
    returns (bool)
  {
    bool exist = false;
    if (ERC1155(nft).balanceOf(address(this), tokenId) == 1) {
      exist = true;
    }
    return exist;
  }

  // Called by bridge service
  function _withdraw(
    address _to,
    uint256 _tokenId,
    address _nftAddress
  ) external onlyOwner {
    require(_to != address(0), "to address cannot be the zero address");
    require(_nftAddress != address(0), "nft address cannot be the zero address");
    if (_exists(_tokenId, _nftAddress)) {
      nfts[_nftAddress].safeTransferFrom(msg.sender, _to, _tokenId, 1, "0x0");
    } else {
      nfts[_nftAddress].mint(_to, _tokenId);
    }
  }

  function deposit(uint256 _nftID, address _nftAddress) external {
    require(
      IERC1155(_nftAddress).isApprovedForAll(msg.sender, address(this)),
      "approve missing"
    );

    IERC1155(_nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _nftID,
      1,
      "0x0"
    );
    emit Deposit(_nftAddress, msg.sender, _nftID);
  }

  function _setURI(string memory uri_, address nft) external onlyOwner {
    nfts[nft].setURI(uri_);
  }
    function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes memory
  ) public pure override returns (bytes4) {
    return
      bytes4(
        keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")
      );
  }

    function supportsInterface(bytes4 interfaceId)
    public
    pure
    override
    returns (bool)
  {
    return
      interfaceId == type(IERC1155Receiver).interfaceId;
  }

  function onERC1155BatchReceived(
    address,
    address,
    uint256[] memory,
    uint256[] memory,
    bytes memory
  ) public pure override returns (bytes4) {
    return
      bytes4(
        keccak256(
          "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
        )
      );
  }
}