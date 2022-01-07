pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DevitaId is ERC1155, AccessControl {
  uint256 public currentTokenId = 0;
  address public tokenUser;
  bool public initialized;
  bool public isMintable;

  constructor() ERC1155("") {}

  function initialize(
    address sender,
    address owner,
    string memory newuri
  ) public {
    require(!initialized, "DevitaId can only be initialized once");
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
    _setURI(newuri);
    tokenUser = sender;
    isMintable = true;
    initialized = true;
  }

  modifier isInitialized() {
    require(initialized, "can only be called after initialization");
    _;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, AccessControl)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function burn(uint256 tokenId)
    public
    isInitialized
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    _burn(tokenUser, tokenId, balanceOf(tokenUser, tokenId));
    isMintable = true;
  }

  function burnBatch(uint256[] memory tokenIds)
    public
    isInitialized
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    uint256[] memory totalAmounts = new uint256[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
      totalAmounts[i] = balanceOf(tokenUser, tokenIds[i]);
    }

    _burnBatch(tokenUser, tokenIds, totalAmounts);
    isMintable = true;
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public pure override(ERC1155) {
    require(false, "can't transfer id");
  }

  function safeBatchTransferFrom(
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) public pure override(ERC1155) {
    require(false, "can't transfer id");
  }

  function mint(
    uint256 amount,
    bytes memory data,
    address recipient
  ) public isInitialized onlyRole(DEFAULT_ADMIN_ROLE) {
    require(isMintable, "token must be burnt first before it can be reminted");
    tokenUser = recipient;
    _mint(tokenUser, currentTokenId, amount, data);
    currentTokenId += 1;
    isMintable = false;
  }

  function mintBatch(
    uint256[] memory amounts,
    bytes memory data,
    address recipient
  ) public isInitialized onlyRole(DEFAULT_ADMIN_ROLE) {
    require(isMintable, "tokens must be burnt first before it can be reminted");
    uint256[] memory allIds = new uint256[](amounts.length);
    for (uint256 i = 0; i < amounts.length; i++) {
      allIds[i] = currentTokenId;
      currentTokenId += 1;
    }

    tokenUser = recipient;
    _mintBatch(tokenUser, allIds, amounts, data);
    isMintable = false;
  }
}