// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Author: Francesco Sullo <[email protected]>

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//import "hardhat/console.sol";

contract SynCityPasses is ERC721, ERC721Enumerable, Ownable {
  using Address for address;
  using Counters for Counters.Counter;

  event ValidatorAndOperatorSet(address validator, address operator);
  event BaseURIUpdated();

  Counters.Counter private _tokenIdTracker;

  struct Conf {
    uint16 maxTokenId;
    uint16[3] remaining;
  }

  Conf private _conf;

  function getRemaining() external view returns (uint16[3] memory) {
    return _conf.remaining;
  }

  string private _baseTokenURI;
  bool private _baseTokenURIFrozen;

  using ECDSA for bytes32;
  using SafeMath for uint256;

  address public validator;
  address public operator;
  mapping(bytes32 => bool) public usedCodes;

  constructor(string memory baseTokenURI) ERC721("Syn City Passes", "SYNPASS") {
    _tokenIdTracker.increment(); // < starts from 1
    _baseTokenURI = baseTokenURI;
    uint16[3] memory remaining = [
      750, // alternate reality game solutions
      8, // team treasury
      19 // community events
    ];
    _conf = Conf({maxTokenId: 777, remaining: remaining});
  }

  function setValidatorAndOperator(address validator_, address operator_) external onlyOwner {
    require(validator_ != address(0), "validator cannot be 0x0");
    require(operator_ != address(0), "operator cannot be 0x0");
    validator = validator_;
    operator = operator_;
    emit ValidatorAndOperatorSet(validator, operator);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  function _mintToken(address to) internal {
    require(_tokenIdTracker.current() <= _conf.maxTokenId, "distribution ended");
    require(to != address(0), "invalid sender");
    require(balanceOf(to) == 0, "one pass per wallet");
    _safeMint(to, _tokenIdTracker.current());
    _tokenIdTracker.increment();
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function updateBaseTokenURI(string memory uri) external onlyOwner {
    require(!_baseTokenURIFrozen, "token uri has been frozen");
    _baseTokenURI = uri;
    emit BaseURIUpdated();
  }

  function freezeBaseTokenURI() external onlyOwner {
    _baseTokenURIFrozen = true;
  }

  function contractURI() external view returns (string memory) {
    return _baseTokenURI;
  }

  function claimFreeToken(
    bytes32 authCode,
    uint256 typeIndex,
    bytes memory signature
  ) external {
    require(!usedCodes[authCode], "authCode already used");
    require(_conf.remaining[typeIndex] > 0, "no more tokens in this category");
    require(isSignedByValidator(encodeForSignature(_msgSender(), authCode, typeIndex), signature), "invalid signature");
    _mintToken(_msgSender());
    _conf.remaining[typeIndex]--;
    usedCodes[authCode] = true;
  }

  function giveawayTokens(address[] memory recipients) external onlyOwner {
    for (uint256 i = 0; i < recipients.length; i++) {
      _mintToken(recipients[i]);
    }
  }

  function isSignedByValidator(bytes32 _hash, bytes memory _signature) public view returns (bool) {
    return validator != address(0) && validator == ECDSA.recover(_hash, _signature);
  }

  function encodeForSignature(
    address recipient,
    bytes32 authCode,
    uint256 typeIndex
  ) public pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          "\x19\x01", // EIP-191
          recipient,
          authCode,
          typeIndex
        )
      );
  }
}