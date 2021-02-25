// This file is generated for the "ropsten" network
// by the 'generate-PollenAddresses_sol.js' script.
// Do not edit it directly - updates will be lost.
// SPDX-License-Identifier: MIT
pragma solidity >=0.6 <0.7.0;


/// @dev Network-dependant params (i.e. addresses, block numbers, etc..)
contract PollenParams {

    // Pollen contracts addresses
    address internal constant pollenDaoAddress = 0x5b1d3D9962D3fb2a6f100ffED908075eb960eBaa;
    address internal constant plnTokenAddress = 0xc0f1ea4487B4CE4dde99998F2da138Ea6Ed6b36B;
    address internal constant stemTokenAddress = 0x03106e05171D3CC97dab28cA2dE4FE338bE42d85;
    address internal constant rateQuoterAddress = 0xE7cc4E3Ea9AB8A82ff8b8c132034456A2A058E02;

    // STEM minting params
    uint32 internal constant mintStartBlock = 9510000;
    uint32 internal constant mintBlocks = 9200000; // ~ 46 months
    uint32 internal constant extraMintBlocks = 600000; // ~ 92 days

    // STEM vesting pools
    address internal constant rewardsPoolAddress = 0x5b1d3D9962D3fb2a6f100ffED908075eb960eBaa;
    address internal constant foundationPoolAddress = 0x64662e7849A3cF25821777FF5e663755a4121C87;
    address internal constant reservePoolAddress = 0xe67903512d7b24C187868edCE5886a4799311C0e;
    address internal constant marketPoolAddress = 0xCCE2842974E8aC64b845Abfe87EeF4Ba6665ede1;
    address internal constant foundersPoolAddress = 0xc45c40E871CAf671486517dEE4E05f9338cA1732;

    // Min STEM vesting rewarded by `PollenDAO.updateRewardPool()`
    uint256 internal constant minVestedStemRewarded = 100 * 1e18;

    // Default voting terms
    uint32 internal constant defaultVotingExpiryDelay = 7200;
    uint32 internal constant defaultExecutionOpenDelay = 1800;
    uint32 internal constant defaultExecutionExpiryDelay = 7200;
}