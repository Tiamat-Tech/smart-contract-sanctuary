// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.0;

import "../../interfaces/ICoverStake.sol";
import "../../libraries/ProtoUtilV1.sol";
import "../../libraries/CoverUtilV1.sol";
import "../../libraries/StoreKeyUtil.sol";
import "../../libraries/ValidationLibV1.sol";
import "../../libraries/NTransferUtilV2.sol";
import "../Recoverable.sol";

/**
 * @title Cover Stake
 * @dev When you create a new cover, you have to specify the amount of
 * NPM tokens you wish to stake as a cover creator. <br /> <br />
 *
 * To demonstrate support for a cover pool, anyone can add and remove
 * NPM stakes (minimum required). The higher the sake, the more visibility
 * the contract gets if there are multiple cover contracts with the same name
 * or similar terms. Even when there are no duplicate contract, a higher stake
 * would normally imply a better cover pool commitment.
 */
contract CoverStake is ICoverStake, Recoverable {
  using ProtoUtilV1 for bytes;
  using ProtoUtilV1 for IStore;
  using StoreKeyUtil for IStore;
  using CoverUtilV1 for IStore;
  using ValidationLibV1 for IStore;
  using NTransferUtilV2 for IERC20;
  using RoutineInvokerLibV1 for IStore;

  /**
   * @dev Constructs this contract
   * @param store Provide the store contract instance
   */
  constructor(IStore store) Recoverable(store) {} // solhint-disable-line

  /**
   * @dev Increase the stake of the given cover pool
   * @param key Enter the cover key
   * @param account Enter the account from where the NPM tokens will be transferred
   * @param amount Enter the amount of stake
   * @param fee Enter the fee amount. Note: do not enter the fee if you are directly calling this function.
   */
  function increaseStake(
    bytes32 key,
    address account,
    uint256 amount,
    uint256 fee
  ) external override nonReentrant {
    // @suppress-acl Can only be accessed by the latest cover contract
    s.mustNotBePaused();
    s.mustBeValidCoverKey(key);
    s.callerMustBeCoverContract();

    require(amount >= fee, "Invalid fee");

    s.npmToken().ensureTransferFrom(account, address(this), amount);

    if (fee > 0) {
      s.npmToken().ensureTransferFrom(address(this), s.getBurnAddress(), fee);
      emit FeeBurned(key, fee);
    }

    s.addUintByKeys(ProtoUtilV1.NS_COVER_STAKE, key, amount - fee);
    s.addUintByKeys(ProtoUtilV1.NS_COVER_STAKE_OWNED, key, account, amount - fee);

    emit StakeAdded(key, amount - fee);
  }

  /**
   * @dev Decreases the stake from the given cover pool
   * @param key Enter the cover key
   * @param account Enter the account to decrease the stake of
   * @param amount Enter the amount of stake to decrease
   */
  function decreaseStake(
    bytes32 key,
    address account,
    uint256 amount
  ) external override nonReentrant {
    // @todo this function is not called anywhere. Remove this.
    // @suppress-acl Can only be accessed by the latest cover contract
    s.mustNotBePaused();
    s.mustBeValidCoverKey(key);
    s.callerMustBeCoverContract();

    uint256 drawingPower = _getDrawingPower(key, account);
    require(drawingPower >= amount, "Exceeds your drawing power");

    s.subtractUintByKeys(ProtoUtilV1.NS_COVER_STAKE, key, amount);
    s.subtractUintByKeys(ProtoUtilV1.NS_COVER_STAKE_OWNED, key, account, amount);

    s.npmToken().ensureTransfer(account, amount);

    // Remove if the strategy is being invoked on the cover contract during this transaction
    s.updateStateAndLiquidity(key);

    emit StakeRemoved(key, amount);
  }

  /**
   * @dev Gets the stake of an account for the given cover key
   * @param key Enter the cover key
   * @param account Specify the account to obtain the stake of
   * @return Returns the total stake of the specified account on the given cover key
   */
  function stakeOf(bytes32 key, address account) public view override returns (uint256) {
    return s.getUintByKeys(ProtoUtilV1.NS_COVER_STAKE_OWNED, key, account);
  }

  /**
   * @dev Gets the drawing power of (the stake amount that can be withdrawn from)
   * an account.
   * @param key Enter the cover key
   * @param account Specify the account to obtain the drawing power of
   * @return Returns the drawing power of the specified account on the given cover key
   */
  function _getDrawingPower(bytes32 key, address account) private view returns (uint256) {
    uint256 yourStake = stakeOf(key, account);
    bool isOwner = account == s.getCoverOwner(key);

    uint256 minStake = s.getMinCoverCreationStake();

    return isOwner ? yourStake - minStake : yourStake;
  }

  /**
   * @dev Version number of this contract
   */
  function version() external pure override returns (bytes32) {
    return "v0.1";
  }

  /**
   * @dev Name of this contract
   */
  function getName() external pure override returns (bytes32) {
    return ProtoUtilV1.CNAME_COVER_STAKE;
  }
}