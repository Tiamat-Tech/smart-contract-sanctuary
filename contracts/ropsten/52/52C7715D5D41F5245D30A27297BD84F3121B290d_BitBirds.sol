// https://ethereum.org/en/developers/tutorials/how-to-write-and-deploy-an-nft/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

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

contract BitBirds is ERC721URIStorage, Ownable {
  // storage variables
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  // events
  event printNewItemId(uint256 _newItemId);

  // modifiers

  // constructor
  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _owner = payable(msg.sender);
  }
  // functions
  function mintNFT(address recipient, string memory tokenURI) public payable returns (uint256) {
    // require(balanceOf(msg.sender) < 2, "You can only purchase 2 tokens");
    require(msg.value == 0.05 ether, "Please send 0.05 ethereum exactly. Check price sent.");
    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();
    _mint(recipient, newItemId);
    _setTokenURI(newItemId, tokenURI);

    emit printNewItemId(newItemId);

    return newItemId;
  }

  function getBalance() public view onlyOwner returns (uint) {
    return address(this).balance;
  }

  function withdrawBalance() public onlyOwner {
    uint balance = getBalance();
    _owner.transfer(balance);
  }
}