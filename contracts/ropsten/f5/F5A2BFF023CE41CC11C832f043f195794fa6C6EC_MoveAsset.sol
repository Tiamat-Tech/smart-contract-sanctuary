pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract MoveAsset {
  address public owner;
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

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  constructor() {
    owner = msg.sender;
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

// Called by bridge service
  function withdraw(uint256 _nftID, address _nftAddress) external onlyOwner {
    IERC1155(_nftAddress).safeTransferFrom(
      address(this),
      msg.sender,
      _nftID,
      1,
      "0x0"
    );
    emit Withdraw(_nftAddress, msg.sender, _nftID);
  }
}