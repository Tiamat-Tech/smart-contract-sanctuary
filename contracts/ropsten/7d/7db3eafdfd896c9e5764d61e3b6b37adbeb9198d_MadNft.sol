pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC1155PresetMinterPauserUpgradeable as ERC1155Base } from "@openzeppelin/contracts-upgradeable/token/ERC1155/presets/ERC1155PresetMinterPauserUpgradeable.sol";
// import { IERC2981Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import { ECDSAUpgradeable as ECDSA } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { StringsUpgradeable as Strings } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import { IRoyaltyBase } from "./IRoyaltyBase.sol";

contract MadNft is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  ERC1155Base,
  EIP712Upgradeable,
  IRoyaltyBase
{
  using ECDSA for bytes32;

  struct InstantMintSubject {
    address user;
    uint256 tokenId;
    uint256 tokenAmount;
    uint256 mintPrice;
  }

  struct InstantMintBatchSubject {
    address user;
    uint256[] tokenIds;
    uint256[] tokenAmounts;
    uint256[] mintPrices;
  }

  bytes32 public constant MINT_PAYLOAD_HASH = keccak256("InstantMintSubject(address user,uint256 tokenId,uint256 tokenAmount,uint256 mintPrice)");

  bytes32 public constant MINT_BATCH_PAYLOAD_HASH = keccak256("InstantMintBatchSubject(address user,uint256[] tokenIds,uint256[] tokenAmounts,uint256[] mintPrices)");

  address public fundAccount;

  // Upgrade: 2022-02-01
  string public name;
  string public symbol;

  mapping(uint256 => address) public creators;

  uint256 public royaltyPercentageForCreator; // 100 for 1%
  uint256 public royaltyPercentageForAdmin;

  // Upgrade functions
  function initialize(string memory _baseURI) public override initializer {
    name = "MADinArt NFT";
    symbol = "MAD";
    __Ownable_init();
    __EIP712_init_unchained("MadInArt NFT", "1");
    super.initialize(_baseURI);
  }

  function _authorizeUpgrade(address) internal override onlyOwner {}

  function upgrade(string memory _name, string memory _symbol, string memory _baseURI) public onlyOwner {
    name = _name;
    symbol = _symbol;
    _setURI(_baseURI);
  }

  function setFundAccount(address _fundAccount) public onlyOwner {
    fundAccount = _fundAccount;
  }

  function withdrawFunds() public onlyOwner {
    require(fundAccount != address(0), "Fund account not set");
    payable(fundAccount).transfer(address(this).balance);
  }

  // Royalty functions
  function setRoyaltyPercentageForCreator(uint256 _royaltyPercentageForCreator) external override onlyOwner {
    royaltyPercentageForCreator = _royaltyPercentageForCreator;
  }
  function setRoyaltyPercentageForAdmin(uint256 _royaltyPercentageForAdmin) external override onlyOwner {
    royaltyPercentageForAdmin = _royaltyPercentageForAdmin;
  }
  function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
    receiver = creators[tokenId];
    royaltyAmount = (salePrice * royaltyPercentageForCreator) / 10000;
  }
  function royaltyInfoAdmin(uint256 salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
    receiver = fundAccount;
    royaltyAmount = (salePrice * royaltyPercentageForAdmin) / 10000;
  }
  function totalRoyaltyFee(uint256 salePrice) external view override returns (uint256 royaltyFee) {
    royaltyFee = (salePrice * (royaltyPercentageForCreator + royaltyPercentageForAdmin)) / 100;
  }

  // Public or External Functions
  function uri(uint256 _tokenId) public view override returns (string memory) {
    return string(abi.encodePacked(super.uri(_tokenId), Strings.toString(_tokenId)));
  }

  // Alias for `uri` function
  function tokenURI(uint256 _tokenId) public view returns (string memory) {
    return uri(_tokenId);
  }

  function instantMint(InstantMintSubject memory _subject, bytes memory _signature)
    external
    payable
  {
    address buyerAddress = _hashInstantMintSubject(_subject).recover(_signature);
    require(buyerAddress == msg.sender, "You are not the buyer");
    require(msg.value == _subject.mintPrice, "Expected accurate mint cost");

    _mint(_subject.user, _subject.tokenId, _subject.tokenAmount, "");
  }

  function instantMintBatch(InstantMintBatchSubject memory _subject, bytes memory _signature)
    external
    payable
  {
    address buyerAddress = _hashInstantMintBatchSubject(_subject).recover(_signature);
    require(buyerAddress == msg.sender, "You are not the buyer");
    uint256 totalPrice = 0;
    for (uint256 i = 0; i < _subject.tokenIds.length; i++) {
      totalPrice += _subject.mintPrices[i];
    }
    require(msg.value == totalPrice, "Expected accurate mint cost");

    _mintBatch(_subject.user, _subject.tokenIds, _subject.tokenAmounts, "");
  }

  // Internal or Private Functions
  function _hashInstantMintSubject(InstantMintSubject memory _subject)
    internal
    view
    returns (bytes32)
  {
    bytes32 hash = keccak256(
      abi.encode(
        MINT_PAYLOAD_HASH,
        _subject.user,
        _subject.tokenId,
        _subject.tokenAmount,
        _subject.mintPrice
      )
    );
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), hash);
  }
  function _hashInstantMintBatchSubject(InstantMintBatchSubject memory _subject)
    internal
    view
    returns (bytes32)
  {
    bytes32 hash = keccak256(
      abi.encode(
        MINT_BATCH_PAYLOAD_HASH,
        _subject.user,
        keccak256(abi.encodePacked(_subject.tokenIds)),
        keccak256(abi.encodePacked(_subject.tokenAmounts)),
        keccak256(abi.encodePacked(_subject.mintPrices))
      )
    );
    return ECDSA.toTypedDataHash(_domainSeparatorV4(), hash);
  }
}