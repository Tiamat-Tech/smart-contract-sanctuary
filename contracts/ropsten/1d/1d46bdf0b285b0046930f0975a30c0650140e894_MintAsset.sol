//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./NFT.sol";

contract MintAsset is IERC1155Receiver {
  event Deposit(
    address indexed _nftAddressExternal,
    address indexed _from,
    uint256 indexed _nftID
  );

  event Withdraw(
    address indexed _nftAddress,
    address indexed _from,
    uint256 indexed _nftID
  );

  uint256 public ethfee;

  // map of mainnet - l2
  mapping(address => NFT) public nfts;

  // map of l2 - mainnet
  mapping(NFT => address) public nftExternal;

  using EnumerableSet for EnumerableSet.AddressSet;
  EnumerableSet.AddressSet private _allowedBridges;

  address public immutable owner;

  constructor() {
    owner = msg.sender;
    _allowedBridges.add(msg.sender);

  }

  function _addNFT(address _existingNFT) external onlyOwner returns (NFT) {
    NFT nft = new NFT("");
    nfts[_existingNFT] = nft;
    nftExternal[nft] = _existingNFT;
    return nfts[_existingNFT];
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
    if (ERC1155(nfts[nft]).balanceOf(address(this), tokenId) == 1) {
      exist = true;
    }
    return exist;
  }

  // Called by bridge service
  function _withdraw(
    address _to,
    uint256 _tokenId,
    address _nftAddress
  ) external {
    require(_allowedBridges.contains(msg.sender), "not a updater");
    require(_to != address(0), "cannot be the zero");
    require(
      _nftAddress != address(0),
      "cannot be the zero"
    );
    if (_exists(_tokenId, _nftAddress)) {
      nfts[_nftAddress].safeTransferFrom(
        address(this),
        _to,
        _tokenId,
        1,
        "0x0"
      );
    } else {
      nfts[_nftAddress].mint(_to, _tokenId);
    }
  }

  function deposit(uint256 _nftID, address _nftAddress) external payable {
    require(
      IERC1155(_nftAddress).isApprovedForAll(msg.sender, address(this)),
      "approve missing"
    );
        require(msg.value>=ethfee,"missig fee");


    IERC1155(_nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      _nftID,
      1,
      "0x0"
    );
    emit Deposit(nftExternal[NFT(_nftAddress)], msg.sender, _nftID);
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
    return interfaceId == type(IERC1155Receiver).interfaceId;
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

  function _addAllowedBridge(address _allowedBridge) external onlyOwner {
    _allowedBridges.add(_allowedBridge);
  }

  function _removeAllowedBridge(address _allowedBridge) external onlyOwner {
    _allowedBridges.remove(_allowedBridge);
  }

  function _setFee(uint256 fee) external onlyOwner {
    ethfee = fee;
  }
}