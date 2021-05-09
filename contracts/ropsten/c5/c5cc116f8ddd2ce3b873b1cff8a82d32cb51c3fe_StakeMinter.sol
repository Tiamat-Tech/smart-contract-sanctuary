// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '../abstracts/Pausable.sol';
import '../abstracts/ExternallyCallable.sol';

import '../interfaces/IToken.sol';
import '../interfaces/IVCAuction.sol';
import '../interfaces/IStakingV2.sol';
import '../interfaces/IStakingV1.sol';
import '../interfaces/IStakeToken.sol';
import '../interfaces/IStakeMinter.sol';
import '../interfaces/IStakeManager.sol';

contract StakeMinter is IStakeMinter, Pausable, ExternallyCallable {
    /** Structs / Vars ------------------------------------------------------------------- */
    struct Settings {
        uint32 lastSessionIdV2;
        uint32 lastSessionIdV1;
    }

    struct Contracts {
        IToken token;
        IVCAuction vcAuction;
        IStakingV2 stakingV2;
        IStakingV1 stakingV1;
        IStakeToken stakeToken;
        IStakeManager stakeManager;
    }

    Settings internal settings;
    Contracts internal contracts;

    /** Functions ------------------------------------------------------------------------ */

    /** @dev Mint Stake
        Description: staking function which receives AXN and creates the stake - takes as param the amount of AXN and the number of days to be staked
        staking days need to be >0 and lower than max days which is 5555
        @param amount {uint256} - AXN amount to be staked
        @param stakingDays {uint256} - number of days to be staked
    */
    function mintStake(uint256 amount, uint256 stakingDays) external pausable {
        require(stakingDays != 0, 'Staking: Staking days < 1');
        require(stakingDays <= 5555, 'Staking: Staking days > 5555');

        //on stake axion gets burned
        contracts.token.burn(msg.sender, amount);

        //call stake internal method
        mintStakeInternal(amount, stakingDays, msg.sender);
    }

    /** @dev External Mint Stake
        Description: external stake creates a stake for a different account than the caller. It takes an extra param the staker address
        @param amount {uint256} - AXN amount to be staked
        @param stakingDays {uint256} - number of days to be staked
        @param staker {address} - account address to create the stake for
    */
    function externalMintStake(
        uint256 amount,
        uint256 stakingDays,
        address staker
    ) external override onlyExternalCaller pausable {
        require(stakingDays != 0, 'Staking: Staking days < 1');
        require(stakingDays <= 5555, 'Staking: Staking days > 5555');

        mintStakeInternal(amount, stakingDays, staker);
    }

    /** @dev Mint Stake Internal
        Description: Internal functinality for mint stake
        @param amount {uint256} - AXN amount to be staked
        @param stakingDays {uint256} - number of days to be staked
        @param staker {address} - account address to create the stake for
    */
    function mintStakeInternal(
        uint256 amount,
        uint256 stakingDays,
        address staker
    ) internal {
        uint256 stakeId = contracts.stakeManager.createStake(staker, amount, stakingDays);

        contracts.stakeToken.mint(staker, stakeId);
    }

    /** @dev Mint Existing legacy stake
        Description: Turns a l1/l2 stake into a v3 nft stake
        @param id {uint256}

        Modifier: Pausable
     */
    function mintExistingLegacyStake(uint256 id) external pausable {
        mintExistingLegacyStakeInternal(msg.sender, payable(msg.sender), id);
    }

    /** @dev Mint existing legacy stake from
        Description: Manager function to help hacked users
        @param from {address}
        @param to {address payable}
        @param id {uint256} - Id i stake

        Modifier: OnlyManager
     */
    function mintExistingLegacyStakeFrom(
        address from,
        address payable to,
        uint256 id
    ) external onlyManager {
        mintExistingLegacyStakeInternal(from, to, id);
    }

    /** @dev Mint existing legacy stake from
        Description: Internal Functionality
        @param from {address}
        @param to {address payable}
        @param id {uint256} - Id of stake

        Modifier: OnlyManager
     */
    function mintExistingLegacyStakeInternal(
        address from,
        address payable to,
        uint256 id
    ) internal {
        require(id <= settings.lastSessionIdV2, 'STAKE MINTER: invalid stakeId.');
        require(contracts.stakeToken.exists(id) == false, 'STAKE MINTER: stake is v3.');
        require(
            contracts.stakeManager.getStakeWithdrawn(id) == false,
            'STAKE MINTER: stake is withdrawn.'
        );

        // first check if saved in v2
        (
            uint256 amount,
            uint256 start,
            uint256 end,
            uint256 shares,
            uint256 firstInterestDay,
            ,
            bool withdrawn,

        ) = contracts.stakingV2.sessionDataOf(from, id);

        if (shares != 0) {
            // if shares are not 0 it means it is v2 or has been upgraded and saved to v2
            require(withdrawn == false, 'STAKE BURNER: stake withdrawn on v2.');
        } else {
            // otherwise check in v1 if valid v1 id
            require(id <= settings.lastSessionIdV1, 'STAKE BURNER: invalid stakeId.');

            (amount, start, end, shares, firstInterestDay) = contracts.stakingV1.sessionDataOf(
                from,
                id
            );

            require(shares != 0, 'STAKE BURNER: stake withdrawn on v1.');
        }

        contracts.stakeManager.createExistingStake(amount, shares, start, end, id);

        if (from != to) {
            contracts.vcAuction.withdrawDivTokensFromTo(from, to);
            contracts.vcAuction.subTotalSharesOfAndRebalance(from, shares);
            contracts.vcAuction.addTotalSharesOfAndRebalance(to, shares);
        }

        contracts.stakeToken.mint(to, id);
    }

    /** Initialize ------------------------------------------------------------------------ */
    function initialize(address _manager, address _migrator) external initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);
    }

    function init(
        address _auction,
        address _token,
        address _vcAuction,
        address _stakeToken,
        address _stakeReminter,
        address _stakeManager,
        address _stakingV2,
        address _stakingV1
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeReminter);
        _setupRole(EXTERNAL_CALLER_ROLE, _auction);

        contracts.token = IToken(_token);
        contracts.vcAuction = IVCAuction(_vcAuction);
        contracts.stakeToken = IStakeToken(_stakeToken);
        contracts.stakeManager = IStakeManager(_stakeManager);
        contracts.stakingV2 = IStakingV2(_stakingV2);
        contracts.stakingV1 = IStakingV1(_stakingV1);
    }

    function restore(uint32 _lastSessionIdV2, uint32 _lastSessionIdV1) public onlyMigrator {
        settings.lastSessionIdV2 = _lastSessionIdV2;
        settings.lastSessionIdV1 = _lastSessionIdV1;
    }
}