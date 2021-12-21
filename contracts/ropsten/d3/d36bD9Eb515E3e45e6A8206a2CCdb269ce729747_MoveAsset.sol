//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract MoveAsset is IERC1155Receiver {
  address public owner;
  event Deposit(
    address indexed _nftAddress,
    address indexed _from,
    uint256 indexed _nftID,
    bool  _ethdropped
  );

  event Withdraw(
    address indexed _nftAddress,
    address indexed _from,
    uint256 indexed _nftID
  );

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  uint256 public ethfee;

 
  mapping(address => mapping(uint256 => bool)) public ethdropped;


  constructor() {
    owner = msg.sender;
  }

  function deposit(uint256 _nftID, address _nftAddress) external payable  {
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
     emit Deposit(_nftAddress, msg.sender, _nftID,ethdropped[_nftAddress][_nftID]);
     ethdropped[_nftAddress][_nftID]=true;
  }

  function _setFee(uint256 fee) external onlyOwner {
    ethfee =  fee;
  }


  // Called by bridge service
  function _withdraw(address _to, uint256 _tokenID , address _nftAddress) external onlyOwner {
    IERC1155(_nftAddress).safeTransferFrom(
      address(this),
      _to,
      _tokenID,
      1,
      "0x0"
    );
    emit Withdraw(_nftAddress, msg.sender, _tokenID);
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