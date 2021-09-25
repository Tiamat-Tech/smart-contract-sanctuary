// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

/**
 * @title MegaTokens 
 * MegaTokens (modified ERC1155PresetMinterPauser) - See OpenZeppelin
 * /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
*  /// 
 */
contract MegaTokens is ERC1155PresetMinterPauser, IERC2981 {
  bytes32 public constant CAT_ROLE = keccak256("CAT_ROLE");
  address internal _royaltyFeeRecipient;
  uint8 internal _royaltyFee; // out of 1000
  uint8 internal _MAX_ROYALTY_FEE;
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  string internal _contractUri;

  constructor(string memory uri, string memory contractUri, address royaltyFeeRecipient,
        uint8 royaltyFee) ERC1155PresetMinterPauser(uri) {
    _setupRole(CAT_ROLE, _msgSender());
    _contractUri = contractUri;

    _MAX_ROYALTY_FEE = type(uint8).max;
    setRoyaltyFeeRecipient(royaltyFeeRecipient);
    _royaltyFee = type(uint8).max;
    if (royaltyFee != 0) setRoyaltyFee(royaltyFee);
  }

  /**
   * This function is for contract-level metadata. As documented by OpenSea, it should contain the storefront-level metadata for your contract.
   * The URL should return a JSON that contains the following format:
   {
      "name": "Mega Cat Labs | MegaTokens",
      "description": "Mega Tokens are adorable cats primarily for demonstrating the use of NFTs. Adopt one today.",
      "image": "https://megatokens.megacatstudios.com/image.png",
      "external_link": "https://megatokens.megacatstudios.com",
      "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
      "fee_recipient": "0xA97F337c39cccE66adfeCB2BF99C1DdC54C2D721" # Where seller fees will be paid to.
   }
   */
  function contractUri() public view returns (string memory) {
        return _contractUri;
  }

  function setContractUri(string memory newContractUri) public {
      require(hasRole(CAT_ROLE, _msgSender()), "MegaTokens: CAT-REQ");
      _contractUri = newContractUri;
  }

  /**
  * Should look like https://token-cdn-domain/{id}.json where receiver is responsible for interpolating the tokenId where {id} exists in the uri.
  */
  function setUri(string memory newUri) public {
    require(hasRole(CAT_ROLE, _msgSender()), "MegaTokens: CAT-REQ");
    ERC1155._setURI(newUri);
  }

  /* Begin royalty code */
  event SetRoyaltyFee(uint8 royaltyFee);
  event SetRoyaltyFeeRecipient(address indexed royaltyFeeRecipient);

  function royaltyFeeInfo() public view returns (address recipient, uint8 permil) {
        return (_royaltyFeeRecipient, _royaltyFee);
  }

  function royaltyInfo(uint256, uint256 _salePrice) external view override returns (address, uint256) {
      return (_royaltyFeeRecipient, (_salePrice * _royaltyFee) / 1000);
  }

  function setRoyaltyFeeRecipient(address royaltyFeeRecipient) public {
    require(hasRole(CAT_ROLE, _msgSender()), "MegaTokens: CAT-REQ");
      require(royaltyFeeRecipient != address(0), "INVALID_FEE_RECIPIENT");

      _royaltyFeeRecipient = royaltyFeeRecipient;

      emit SetRoyaltyFeeRecipient(royaltyFeeRecipient);
  }

  function setRoyaltyFee(uint8 royaltyFee) public {
    require(hasRole(CAT_ROLE, _msgSender()), "MegaTokens: CAT-REQ");
      if (_royaltyFee == type(uint8).max) {
          require(royaltyFee <= _MAX_ROYALTY_FEE, "INVALID_FEE");
      } else {
          require(royaltyFee < _royaltyFee, "INVALID_FEE");
      }

      _royaltyFee = royaltyFee;

      emit SetRoyaltyFee(royaltyFee);
  }

  /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC1155PresetMinterPauser) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}