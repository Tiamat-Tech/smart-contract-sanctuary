// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./token/PRIVIPodERC1155Token.sol";
import "./interfaces/IBridgeManager.sol";

/**
 * @title   PRIVIPodERC1155Factory contract
 * @dev     Creates new ERC1155 tokens using a factory pattern
 * @author  PRIVI
 **/
contract PRIVIPodERC1155Factory is AccessControl {
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
  address public bridgeManagerAddress;
  uint256 public totalPodCreated;
  mapping(string => address) public podTokenAddressesByUri;
  mapping(string => address) public podTokenAddressesById;

  event PodCreated(string indexed uri, address podAddress);

  /**
   * @dev Grants `DEFAULT_ADMIN_ROLE` and `MODERATOR_ROLE` to the
   * account that deploys the contract.
   *
   */
  constructor(address bridgeAddress) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MODERATOR_ROLE, _msgSender());
    bridgeManagerAddress = bridgeAddress;
  }

  //TODO: getTotalTokenCreated()

  /**
   * @notice  Assigns `MODERATOR_ROLE` to SwapManager contract
   * @param   swapManagerAddress The SwapManager contract address
   */
  function assignRoleSwapManager(address swapManagerAddress) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to assign SwapManager address"
    );
    _setupRole(MODERATOR_ROLE, swapManagerAddress);
  }

  /**
   * @notice Returns the contract address of the Pod token
   * @param  uri The Pod URI
   * @return podAddress The contract address of the Pod token
   */
  function getPodAddressByUri(string calldata uri)
    external
    view
    returns (address podAddress)
  {
    podAddress = podTokenAddressesByUri[uri];
  }

  /**
   * @notice Returns the contract address of the Pod token
   * @param  podId The Pod Id
   * @return podAddress The contract address of the Pod token
   */
  function getPodAddressById(string calldata podId)
    external
    view
    returns (address podAddress)
  {
    podAddress = podTokenAddressesById[podId];
  }

  /**
   * @notice Creates an ERC1155 Pod token and registers it in the BridgeManager
   * @dev    - Pod id must not exist
   * @param  uri The base URI
   */
  function createPod(string calldata uri, string calldata podId)
    external
    returns (address podAddress)
  {
    // TODO: Check if URI already exists in previous token contracts?
    // TODO: Check restrictions to create POD tokens
    // require(
    //   hasRole(MODERATOR_ROLE, _msgSender()),
    //   "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to create pod."
    // );
    require(
      podTokenAddressesById[podId] == address(0),
      "PRIVIPodERC1155TokenFactory: Pod id already exists."
    );
    require(
      podTokenAddressesByUri[uri] == address(0),
      "PRIVIPodERC1155Factory: Pod already exists."
    );
    PRIVIPodERC1155Token podToken =
      new PRIVIPodERC1155Token(uri, address(this));
    podAddress = address(podToken);

    totalPodCreated += 1;

    podTokenAddressesByUri[uri] = podAddress;
    podTokenAddressesById[podId] = podAddress;

    IBridgeManager(bridgeManagerAddress).registerTokenERC1155(
      uri,
      uri,
      podAddress
    );

    emit PodCreated(uri, podAddress);
  }

  /**
   * @notice Mints ERC721 Pod tokens
   * @dev    - The caller must be MODERATOR_ROLE
   *         - `account` address can't be zero
   * @param  uri The base URI
   * @param  account The destination account to receive minted tokens
   * @param  tokenId The Pod token identifier
   * @param  amount The amount of tokens to be minted
   * @param  data The data to be added (currently not used)
   */
  function mintPodTokenByUri(
    string calldata uri,
    address account,
    uint256 tokenId,
    uint256 amount,
    bytes calldata data
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to invest for investor"
    );
    require(
      account != address(0),
      "PRIVIPodERC1155Factory: Account address should not be zero"
    );
    require(amount > 0, "PRIVIPodERC1155Factory: amount should not be zero");

    PRIVIPodERC1155Token(podTokenAddressesByUri[uri]).mint(
      account,
      tokenId,
      amount,
      data
    );
  }

  /**
   * @dev Moderator will mint the amount of pod token for the investor"s account
   *
   * Requirements:
   *
   * - the caller must MODERATOR_ROLE to perform this action.
   */
  function mintPodTokenById(
    string calldata podId,
    address account,
    uint256 tokenId,
    uint256 amount,
    bytes memory data
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to invest for investor."
    );
    require(
      account != address(0),
      "PRIVIPodERC1155Factory: Account address should not be zero."
    );
    require(amount > 0, "PRIVIPodERC1155Factory: amount should not be zero.");
    
    PRIVIPodERC1155Token(podTokenAddressesById[podId]).mint(
      account,
      tokenId,
      amount,
      data
    );
  }

  /**
   * @dev Moderator will mint the amount of pod token for the investor"s account
   *
   * Requirements:
   *
   * - the caller must MODERATOR_ROLE to perform this action.
   */
  function batchMintPodTokenByUri(
    string calldata uri,
    address account,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    bytes calldata data
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to invest for investor"
    );
    require(
      account != address(0),
      "PRIVIPodERC1155Factory: Account address should not be zero"
    );
    PRIVIPodERC1155Token(podTokenAddressesByUri[uri]).mintBatch(
      account,
      tokenIds,
      amounts,
      data
    );
  }

  /**
   * @dev Moderator will mint the amount of pod token for the investor"s account
   *
   * Requirements:
   *
   * - the caller must MODERATOR_ROLE to perform this action.
   */
  function batchMintPodTokenById(
    string calldata podId,
    address account,
    uint256[] memory tokenIds,
    uint256[] memory amounts,
    bytes calldata data
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC1155Factory: must have MODERATOR_ROLE to invest for investor."
    );
    require(
      account != address(0),
      "PRIVIPodERC1155Factory: Account address should not be zero."
    );
    PRIVIPodERC1155Token(podTokenAddressesById[podId]).mintBatch(
      account,
      tokenIds,
      amounts,
      data
    );
  }
}