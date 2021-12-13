// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./nft.contract.sol";

contract WalletContract is Context, Ownable {

  // Mapping from token ID to owner address for deposited tokens
  mapping(uint256 => address) private _owners;

  // Address of NFT smart contract to interact with
  address private _nftContractAddress;

  /**
   * @dev Emitted when `tokenId` token is deposited to wallet.
   */
  event Deposit(address indexed owner, uint256 indexed tokenId);

  /**
   * @dev Emitted when `tokenId` token is withdrew from wallet.
   */
  event Withdraw(address indexed owner, uint256 indexed tokenId);

  /**
    * @dev Initializes the contract by setting a `nftContractAddress` which wallet interact with.
    */
  constructor(address nftContractAddress_) {
    _setNftContractAddress(nftContractAddress_);
  }

  /**
    * @dev Transfer `tokenId` from owner to wallet. Create record to mapping _owners
    *
    * Requirements:
    *
    * - `tokenId` token must be approved by owner to wallet contract address in advice.
    * - the caller must be owner of `tokenId`.
    * - the NFT contract must not be paused.
    *
    * Emits a {Deposit} event.
    */
  function deposit(uint256 tokenId) public {
    address msgSender = _msgSender();
    NftContract nftContract = NftContract(getNftContractAddress());
    require(nftContract.ownerOf(tokenId) == msgSender, "Wallet: only owner of token can deposit it");
    nftContract.transferFrom(msgSender, address(this), tokenId);
    _owners[tokenId] = msgSender;
    emit Deposit(msgSender, tokenId);
  }

  /**
    * @dev Withdraw `tokenId` from wallet to owner. Delete record from mapping _owners
    *
    * Requirements:
    *
    * - the caller must be owner who deposited `tokenId` token to wallet.
    * - the NFT contract must not be paused.
    *
    * Emits a {Withdraw} event.
    */
  function withdraw(uint256 tokenId) public {
    address msgSender = _msgSender();
    NftContract nftContract = NftContract(getNftContractAddress());
    require(ownerOf(tokenId) == msgSender, "Wallet: only owner of token can withdraw it");
    delete _owners[tokenId];
    nftContract.transferFrom(address(this), msgSender, tokenId);
    emit Withdraw(msgSender, tokenId);
  }

  /**
     * @dev Returns the owner of the `tokenId` token if it was deposited to wallet.
     *
     * Requirements:
     *
     * - `tokenId` must be deposited to wallet.
     */
  function ownerOf(uint256 tokenId) public view returns (address) {
    address owner = _owners[tokenId];
    require(owner != address(0), "Wallet: owner query for nonexistent token");
    return owner;
  }

  /**
    * @dev Returns the address of the NFT smart contract.
    */
  function getNftContractAddress() public view returns (address) {
    return _nftContractAddress;
  }

  /**
    * @dev See {Wallet-_setNftContractAddress}.
    */
  function setNftContractAddress(address nftContractAddress) public onlyOwner {
    _setNftContractAddress(nftContractAddress);
  }

  /**
    * @dev Set new NFT smart contract address.
    *
    * Requirements:
    *
    * - the caller must be contract owner.
    * - `nftContractAddress` cannot be the zero address.
    */
  function _setNftContractAddress(address nftContractAddress) private {
    require(nftContractAddress != address(0), "Wallet: new NFT smart contract address is the zero address");
    _nftContractAddress = nftContractAddress;
  }
}