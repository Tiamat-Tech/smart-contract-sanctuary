// https://ethereum.org/en/developers/tutorials/how-to-write-and-deploy-an-nft/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "hardhat/console.sol";

abstract contract Ownable is Context {
  address payable public _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
    * @dev Initializes the contract setting the deployer as the initial owner.
    */
  constructor() {
    _transferOwnership(payable(_msgSender()));
  }

  /**
    * @dev Throws if called by any account other than the owner.
    */
  modifier onlyOwner() {
      require(_owner == _msgSender(), "Ownable: caller is not the owner");
      _;
  }

  /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Can only be called by the current owner.
    */
  function transferOwnership(address payable newOwner) public virtual onlyOwner {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      _transferOwnership(newOwner);
  }

  /**
    * @dev Transfers ownership of the contract to a new account (`newOwner`).
    * Internal function without access restriction.
    */
  function _transferOwnership(address payable newOwner) internal virtual {
      address oldOwner = _owner;
      _owner = newOwner;
      emit OwnershipTransferred(oldOwner, newOwner);
  }
}

/// @title A function that mints NFT tokens
/// @author kyle reynolds
contract BitBirds is ERC721URIStorage, Ownable {
  /// @dev storage variables
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  /// @dev events
  event printNewItemId(uint256 _newItemId);

  /// @dev modifiers placeholder

  /// @dev constructor
  /// @dev SWC-118 Incorrect Constructor Name vector attack protection
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _owner = payable(msg.sender);
  }

  /// @dev functions
  function mintNFT(address recipient, string memory tokenURI) public payable returns (uint256) {
    require(balanceOf(msg.sender) < 2, "You can only purchase 2 tokens");
    /// @dev SWC-105 Unprotected Ether Withdrawal vector attack protection
    require(msg.value == 0.05 ether, "Please send 0.05 ethereum exactly. Check price sent.");
    /// @dev increment token id by 1, starting at 1
    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();
    _mint(recipient, newItemId);
    /// @dev assign newItemId with tokenUri
    _setTokenURI(newItemId, tokenURI);

    /// @dev emit newItemId for frontend
    emit printNewItemId(newItemId);

    return newItemId;
  }

  /// @dev function get contract balance
  function getBalance() public view onlyOwner returns (uint) {
    return address(this).balance;
  }

  /// @dev withdraw balance to owner
  function withdrawBalance() public onlyOwner {
    /// @dev SWC-132 Unexpected Ether balance vector attack protection
    require(getBalance() > 0, "There is no ether to withdraw");
    _owner.transfer(getBalance());
  }
}