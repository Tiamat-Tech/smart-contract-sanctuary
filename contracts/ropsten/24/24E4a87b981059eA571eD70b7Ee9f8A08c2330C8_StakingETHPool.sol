// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../openzeppelin/access/AccessControl.sol";
import { StorageETHPoolLib } from "./lib/StorageETHPool.sol";
import { StakingETHPoolImpl } from "./impl/StakingETHPoolImpl.sol";
import { IStakeETHPool } from "./interface/IStakeETHPool.sol";

import { State } from "./State.sol";

contract StakingETHPool is State, AccessControl {
	//@aaiello: this should be in an interface so is easy to import to other contracts,
	//but we should create an abstract contract in the middle and is no important for the scope of this test
	event LogRewardAdded(address indexed account, uint256 amount);
	event LogStake(address indexed account, uint256 amount);
	event LogUnstake(address indexed account, uint256 amount);

	using StorageETHPoolLib for StorageETHPoolLib.State;
	bytes32 public constant ETHPOOL_ROLE = "EP";

	modifier onlyTeam() {
		require(hasRole(ETHPOOL_ROLE, msg.sender), "ACCESS DENY");
		_;
	}

	function addMember(address member) public virtual onlyTeam {
		require(member != address(0), "member cant be zero address");
		grantRole(ETHPOOL_ROLE, member);
	}

	//@aaiello: we should use initialize if we want to be upgradable. But for store money contracts is recomenable constructor because audits validate not to be upgradable
	constructor() {
		g_state.initialTimeStamp = block.timestamp;
		g_state.stakedAmount = 0;
		g_state.rewardsCounter = 1;
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(ETHPOOL_ROLE, msg.sender);
	}

	function found(uint256 val) public payable onlyTeam {
		StakingETHPoolImpl.found(g_state, val);
		emit LogRewardAdded(msg.sender, val);
	}

	function stake(uint256 val) public payable {
		StakingETHPoolImpl.stake(g_state, msg.sender, val);
		emit LogStake(msg.sender, val);
	}

	function unstake() public payable {
		uint256 val = StakingETHPoolImpl.unstake(g_state, msg.sender);
		emit LogUnstake(msg.sender, val);
	}

	receive() external payable {}
}