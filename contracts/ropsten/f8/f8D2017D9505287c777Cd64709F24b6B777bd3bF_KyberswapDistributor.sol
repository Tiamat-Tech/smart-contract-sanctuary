// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.9;

import {ReentrancyGuard} from '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {MerkleProof} from '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import {IKyberswapDistributor} from '../interfaces/distributor/IKyberswapDistributor.sol';

/**
 * @title Distributor contract for Kyberswap
 *
 **/
contract KyberswapDistributor is IKyberswapDistributor, Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;
  using Address for address payable;

  uint256 public phaseId;

  //phaseId => Distribution
  mapping(uint256 => Distribution) public distributionInfo;
  // wallet => phase id => token => claimedAmount
  mapping(address => mapping(uint256 => mapping(IERC20 => uint256))) public claimedAmounts;

  constructor(address admin) {
    transferOwnership(admin);
  }

  receive() external payable {}

  /**
   * @dev Allow owner to withdraw reward tokens
   */
  function ownerWithdraw(IERC20[] calldata tokens, uint256[] calldata amounts)
    external
    override
    onlyOwner
  {
    for (uint256 i = 0; i < tokens.length; i++) {
      if (tokens[i] == IERC20(address(0))) {
        payable(_msgSender()).sendValue(amounts[i]);
      } else {
        tokens[i].safeTransfer(_msgSender(), amounts[i]);
      }
    }
  }

  /**
   * @dev Claim accumulated rewards for a set of tokens at a phase
   * @param id phase id number
   * @param index user reward info index in the array of reward info
   * during merkle tree generation
   * @param user wallet address of reward beneficiary
   * @param tokens array of tokens claimable by reward beneficiary
   * @param amounts cumulative token amounts claimable by reward beneficiary
   * @param merkleProof merkle proof of claim
   **/
  function claim(
    uint256 id,
    uint256 index,
    address user,
    IERC20[] calldata tokens,
    uint256[] calldata amounts,
    bytes32[] calldata merkleProof
  ) external override nonReentrant {
    // verify if can claim
    require(isValidClaim(id, index, user, tokens, amounts, merkleProof), 'invalid claim data');
    uint256[] memory claimAmounts = new uint256[](tokens.length);

    // claim each token
    for (uint256 i = 0; i < tokens.length; i++) {
      // if none claimable, skip
      if (amounts[i] == 0) continue;

      uint256 claimable = amounts[i] - claimedAmounts[user][id][tokens[i]];
      if (claimable == 0) continue;

      if (tokens[i] == IERC20(address(0))) {
        payable(user).sendValue(claimable);
      } else {
        tokens[i].safeTransfer(user, claimable);
      }
      claimedAmounts[user][id][tokens[i]] = claimable;
      claimAmounts[i] = claimable;
    }
    emit Claimed(id, user, tokens, claimAmounts);
  }

  /// @notice Propose a new phase distribution, only by admin
  function proposeDistribution(
    bytes32 root,
    uint256 deadline,
    string memory content
  ) external override onlyOwner {
    distributionInfo[phaseId] = Distribution(root, deadline, content);
    emit PhaseCreated(phaseId++, root, deadline, content);
  }

  function updateDistributionTime(uint256 id, uint256 newTime) external onlyOwner {
    require(phaseId >= id, 'Invalid phase');
    require(newTime >= _getBlockTime(), 'Invalid time');
    distributionInfo[id].deadline = newTime;
    emit PhaseUpdated(id, newTime);
  }

  /**
   * @dev Fetch claimed rewards for a set of tokens in a phase
   * @param id phase Id number
   * @param user wallet address of reward beneficiary
   * @param tokens array of tokens claimed by reward beneficiary
   * @return userClaimedAmounts claimed token amounts by reward beneficiary in a phase
   **/
  function getClaimedAmounts(
    uint256 id,
    address user,
    IERC20[] calldata tokens
  ) external view override returns (uint256[] memory userClaimedAmounts) {
    userClaimedAmounts = new uint256[](tokens.length);
    for (uint256 i = 0; i < tokens.length; i++) {
      userClaimedAmounts[i] = claimedAmounts[user][id][tokens[i]];
    }
  }

  function encodeClaim(
    uint256 id,
    uint256 index,
    address account,
    IERC20[] calldata tokens,
    uint256[] calldata amounts
  ) external pure returns (bytes memory encodedData, bytes32 encodedDataHash) {
    require(tokens.length == amounts.length, 'bad tokens and amounts length');
    encodedData = abi.encode(id, index, account, tokens, amounts);
    encodedDataHash = keccak256(encodedData);
  }

  /**
   * @dev Checks whether a claim is valid or not
   * @param id phase Id number
   * @param index user reward info index in the array of reward info
   * during merkle tree generation
   * @param user wallet address of reward beneficiary
   * @param tokens array of tokens claimable by reward beneficiary
   * @param amounts reward token amounts claimable by reward beneficiary
   * @param merkleProof merkle proof of claim
   * @return true if valid claim, false otherwise
   **/
  function isValidClaim(
    uint256 id,
    uint256 index,
    address user,
    IERC20[] calldata tokens,
    uint256[] calldata amounts,
    bytes32[] calldata merkleProof
  ) public view override returns (bool) {
    if (tokens.length != amounts.length) return false;
    if (_getBlockTime() >= distributionInfo[id].deadline) return false;
    bytes32 node = keccak256(abi.encode(id, index, user, tokens, amounts));
    return MerkleProof.verify(merkleProof, distributionInfo[id].root, node);
  }

  function _getBlockTime() internal view virtual returns (uint32) {
    return uint32(block.timestamp);
  }
}