// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IGovernanceStrategy.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title Governance Strategy contract
 * @dev Smart contract containing logic to measure users' relative power to propose and vote.
 * User Power = User Power from Aave Token + User Power from stkAave Token.
 * User Power from Token = Token Power + Token Power as Delegatee [- Token Power if user has delegated]
 * Two wrapper functions linked to Aave Tokens's GovernancePowerDelegationERC20.sol implementation
 * - getPropositionPowerAt: fetching a user Proposition Power at a specified block
 * - getVotingPowerAt: fetching a user Voting Power at a specified block
 **/
contract GovernanceStrategy is IGovernanceStrategy {
  address public LOTTO;
  address public GAME_LOTTO;

  /**
   * @dev Constructor, register tokens used for Voting and Proposition Powers.
   * @param lotto The address of the AAVE Token contract.
   * @param gLotto The address of the stkAAVE Token Contract
   **/
  constructor(address lotto, address gLotto){
    LOTTO = lotto;
    GAME_LOTTO = gLotto;
  }

  /**
   * @dev Returns the total supply of Proposition Tokens Available for Governance
   * = AAVE Available for governance      + stkAAVE available
   * The supply of AAVE staked in stkAAVE are not taken into account so:
   * = (Supply of AAVE - AAVE in stkAAVE) + (Supply of stkAAVE)
   * = Supply of AAVE, Since the supply of stkAAVE is equal to the number of AAVE staked
   * @return total supply at blockNumber
   **/
  function getTotalVotingSupply() public view override returns (uint256) {
    return IERC20(LOTTO).totalSupply();
  }

  /**
   * @dev Returns the Vote Power of a user at a specific block number.
   * @param user Address of the user.
   * @return Vote number
   **/
  function getVotingPower(address user)
    public
    view
    override
    returns (uint256)
  {
    return _getPower(user);
  }

  function _getPower(
    address user
  ) internal view returns (uint256) {
    return
      IERC20(LOTTO).balanceOf(user) + IERC20(GAME_LOTTO).balanceOf(user);
  }
}