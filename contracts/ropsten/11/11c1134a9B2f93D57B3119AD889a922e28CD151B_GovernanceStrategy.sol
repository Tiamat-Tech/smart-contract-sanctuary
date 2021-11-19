// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IGovernanceStrategy.sol';
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title Governance Strategy contract
 * @dev Smart contract containing logic to measure users' relative power to propose and vote.
 * User Power = User Power from Lotto Token + User Power from Game Lotto Token.
 **/
contract GovernanceStrategy is IGovernanceStrategy {
  address public LOTTO;
  address public GAME_LOTTO;

  /**
   * @dev Constructor, register tokens used for Power.
   * @param lotto The address of the Lotto Token contract.
   * @param gLotto The address of the gLotto Token Contract
   **/
  constructor(address lotto, address gLotto){
    LOTTO = lotto;
    GAME_LOTTO = gLotto;
  }

  /**
   * @dev Returns the total supply of Proposition Tokens Available for Governance
   * Voting supply will be equal Lotto supply. Cause the supply of Game lotto will be equal 
   * to the locked in the staking contract lotto tokens 
   * @return total supply 
   **/
  function getTotalVotingSupply() public view override returns (uint256) {
    return IERC20(LOTTO).totalSupply();
  }

  /**
   * @dev Returns the Vote Power of a user.
   * @param user Address of the user.
   * @return Vote number
   **/
  function getVotingPower(address user)
    public
    view
    override
    returns (uint256)
  {
    return  IERC20(LOTTO).balanceOf(user) + IERC20(GAME_LOTTO).balanceOf(user);
  }
}