// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./token/PRIVIPodERC20Token.sol";
import "./interfaces/IBridgeManager.sol";

/**
 * @title   PRIVIPodERC20Factory contract
 * @dev     Creates new ERC20 tokens using a factory pattern
 * @author  PRIVI
 **/
contract PRIVIPodERC20Factory is AccessControl {
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
  address public bridgeManagerAddress;
  uint256 private totalPodCreated;
  mapping(string => address) private podTokenAddressesById;
  mapping(string => address) private podTokenAddressesBySymbol;

  event PodCreated(
    string indexed podId,
    string podTokenName,
    string podTokenSymbol
  );

  /**
   * @dev
   * - Grants `DEFAULT_ADMIN_ROLE` and `MODERATOR_ROLE` to the
   *   account that deploys the contract
   * - Assigns the bridgeManager address
   */
  constructor(address bridgeAddress) {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MODERATOR_ROLE, _msgSender());
    bridgeManagerAddress = bridgeAddress;
  }

  /**
   * @notice Assigns `MODERATOR_ROLE` to SwapManager contract
   * @param  swapManagerAddress The SwapManager contract address
   */
  function assignRoleSwapManager(address swapManagerAddress) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC20Factory: must have MODERATOR_ROLE to assign SwapManager address"
    );
    _setupRole(MODERATOR_ROLE, swapManagerAddress);
  }

  /**
   * @notice Returns the total amount of Pod tokens created
   */
  function getTotalTokenCreated() external view returns (uint256 totalPods) {
    totalPods = totalPodCreated;
  }

  /**
   * @notice Returns the contract address of the Pod token
   * @param  podId The Pod token identifier
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
   * @notice Returns the contract address of the Pod token
   * @param  tokenSymbol The Pod token symbol (ticker)
   * @return podAddress The contract address of the Pod token
   */
  function getPodAddressBySymbol(string calldata tokenSymbol)
    external
    view
    returns (address podAddress)
  {
    podAddress = podTokenAddressesBySymbol[tokenSymbol];
  }

  /**
   * @notice Creates an ERC20 Pod token and registers it in the BridgeManager
   * @dev    - Pod id must not exist
   *         - Pod name & symbol must not exist
   *         - Pod name & symbol can't be empty
   *         - Pod symbol can't be greater than 25 characters
   * @param  podId The Pod token identifier
   * @param  podTokenName The Pod token name
   * @param  podTokenSymbol The Pod token symbol (ticker)
   * @return podAddress The contract address of the Pod token created
   */
  function createPod(
    string calldata podId,
    string calldata podTokenName,
    string calldata podTokenSymbol
  ) external returns (address podAddress) {
    // TODO: Check restrictions to create POD tokens
    // require(hasRole(MODERATOR_ROLE, _msgSender()), "PRIVIPodERC20Factory: must have MODERATOR_ROLE to create pod.");
    require(
      podTokenAddressesById[podId] == address(0),
      "PRIVIPodERC20Factory: Pod id already exists"
    );
    require(
      podTokenAddressesBySymbol[podTokenSymbol] == address(0),
      "PRIVIPodERC20Factory: Pod symbol already exists"
    );

    PRIVIPodERC20Token podToken =
      new PRIVIPodERC20Token(podTokenName, podTokenSymbol, address(this));
    podAddress = address(podToken);

    totalPodCreated += 1;

    podTokenAddressesById[podId] = podAddress;
    podTokenAddressesBySymbol[podTokenSymbol] = podAddress;

    IBridgeManager(bridgeManagerAddress).registerTokenERC20(
      podTokenName,
      podTokenSymbol,
      podAddress
    );

    emit PodCreated(podId, podTokenName, podTokenSymbol);
  }

  /**
   * @notice Mints ERC20 Pod tokens
   * @dev    - The caller must MODERATOR_ROLE
   *         - `account` address can't be zero
   *         - 'investAmount` must be greater than zero
   * @param  podId The Pod token identifier
   * @param  account The destination account to receive minted tokens
   * @param  investAmount The amount of tokens to be minted
   */
  function mintPodTokenById(
    string calldata podId,
    address account,
    uint256 investAmount
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC20Factory: must have MODERATOR_ROLE to invest for investor"
    );
    require(
      account != address(0),
      "PRIVIPodERC20Factory: Account address should not be zero"
    );
    require(
      investAmount > 0,
      "PRIVIPodERC20Factory: investAmount should not be zero"
    );

    PRIVIPodERC20Token(podTokenAddressesById[podId]).mint(
      account,
      investAmount
    );
  }

  /**
   * @notice Mints ERC20 Pod tokens
   * @dev    - The caller must MODERATOR_ROLE
   *         - `account` address can't be zero
   *         - 'investAmount` must be greater than zero
   * @param  tokenSymbol The Pod token symbol (sticker)
   * @param  account The destination account to receive minted tokens
   * @param  investAmount The amount of tokens to be minted
   */
  function mintPodTokenBySymbol(
    string calldata tokenSymbol,
    address account,
    uint256 investAmount
  ) external {
    require(
      hasRole(MODERATOR_ROLE, _msgSender()),
      "PRIVIPodERC20Factory: must have MODERATOR_ROLE to invest for investor"
    );
    require(
      account != address(0),
      "PRIVIPodERC20Factory: Account address should not be zero"
    );
    require(
      investAmount > 0,
      "PRIVIPodERC20Factory: investAmount should not be zero"
    );

    PRIVIPodERC20Token(podTokenAddressesBySymbol[tokenSymbol]).mint(
      account,
      investAmount
    );
  }
}