// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';

import '../abstracts/Manageable.sol';
import '../abstracts/Migrateable.sol';
import '../abstracts/ExternallyCallable.sol';

import '../interfaces/IToken.sol';
import '../interfaces/IVCAuction.sol';
import '../interfaces/IStakeManager.sol';
import '../interfaces/IStakingV1.sol';
import '../interfaces/IStakingV21.sol';

contract VCAuction is IVCAuction, Manageable, Migrateable, ExternallyCallable {
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    /** Events */
    event AccountRegistered(address indexed account, uint256 totalShares);

    event WithdrawLiquidDiv(
        address indexed account,
        address indexed tokenAddress,
        uint256 interest
    );

    struct Contracts {
        IStakingV1 stakingV1;
        IStakingV21 stakingV2;
        IStakeManager stakeManager;
    }

    Contracts internal contracts;
    EnumerableSetUpgradeable.AddressSet internal divTokens;

    mapping(address => bool) internal isVcaRegistered;
    mapping(address => uint256) internal totalSharesOf;
    mapping(address => uint256) internal tokenPricePerShare; //price per share for every token that is going to be offered as divident through the VCA
    mapping(address => uint256) internal originWithdrawableTokenAmounts;
    // used for VCA divs calculation. The way the system works is that deductBalances is starting as totalSharesOf x price of the respective token. So when the token price appreciates, the interest earned is the difference between totalSharesOf x new price - deductBalance [respective token]
    mapping(address => mapping(address => int256)) internal deductBalances;

    /* New variables must go below here. */

    modifier ensureIsVcaRegistered(address staker) {
        ensureIsVcaRegisteredInternal(staker);
        _;
    }

    function ensureIsVcaRegisteredInternal(address staker) internal {
        if (isVcaRegistered[staker] == false) {
            if (contracts.stakingV2.getIsVCARegistered(staker) == false) {
                uint256 totalShares = contracts.stakingV2.resolveTotalSharesOf(staker);

                totalSharesOf[staker] = totalShares;
                contracts.stakeManager.addTotalVcaRegisteredShares(totalShares);

                for (uint256 i = 0; i < divTokens.length(); i++) {
                    deductBalances[staker][divTokens.at(i)] = (totalShares *
                        tokenPricePerShare[divTokens.at(i)])
                    .toInt256();
                }
            } else {
                totalSharesOf[staker] = contracts.stakingV2.getTotalSharesOf(staker);
                for (uint256 i = 0; i < divTokens.length(); i++) {
                    deductBalances[staker][divTokens.at(i)] = contracts
                    .stakingV2
                    .getDeductBalances(staker, divTokens.at(i))
                    .toInt256();
                }
            }

            isVcaRegistered[staker] = true;
        }
    }

    //function to withdraw the dividends earned for a specific token
    // @param tokenAddress {address} - address of the dividend token
    function withdrawDivTokens(address tokenAddress) external {
        withdrawDivTokenInternal(msg.sender, payable(msg.sender), tokenAddress);
    }

    function withdrawDivTokensTo(address payable to, address tokenAddress) external {
        withdrawDivTokenInternal(msg.sender, to, tokenAddress);
    }

    function withdrawDivTokensFromTo(address from, address payable to)
        external
        override
        onlyExternalCaller
    {
        for (uint256 i = 0; i < divTokens.length(); i++) {
            withdrawDivTokenInternal(from, to, divTokens.at(i));
        }
    }

    function withdrawDivTokenInternal(
        address from,
        address payable to,
        address tokenAddress
    ) internal ensureIsVcaRegistered(from) {
        require(divTokens.contains(tokenAddress), 'VCAUCTION: invalid token address.');

        uint256 tokenInterestEarned = getTokenInterestEarnedInternal(from, tokenAddress);

        if (tokenInterestEarned == 0) {
            return;
        }

        //after divdents are paid we need to set the deductBalance of that token to current token price * total shares of the account
        deductBalances[from][tokenAddress] = (totalSharesOf[from] *
            tokenPricePerShare[tokenAddress])
        .toInt256();

        /** 0xFF... is our ethereum placeholder address */
        if (tokenAddress != address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)) {
            IERC20Upgradeable(tokenAddress).transfer(to, tokenInterestEarned);
        } else {
            to.transfer(tokenInterestEarned);
        }

        emit WithdrawLiquidDiv(from, tokenAddress, tokenInterestEarned);
    }

    function withdrawOriginDivTokens(address tokenAddress) external onlyExternalCaller {
        /** 0xFF... is our ethereum placeholder address */
        if (tokenAddress != address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)) {
            IERC20Upgradeable(tokenAddress).transfer(
                msg.sender,
                originWithdrawableTokenAmounts[tokenAddress]
            );
        } else {
            payable(msg.sender).transfer(originWithdrawableTokenAmounts[tokenAddress]);
        }

        originWithdrawableTokenAmounts[tokenAddress] = 0;
    }

    // @param accountAddress {address} - address of account
    // @param tokenAddress {address} - address of the dividend token
    function getTokenInterestEarnedInternal(address accountAddress, address tokenAddress)
        internal
        view
        returns (uint256)
    {
        return
            (((totalSharesOf[accountAddress] * tokenPricePerShare[tokenAddress]).toInt256() - // Don't need to pull tokenPricePerShare because we will populate on start
                deductBalances[accountAddress][tokenAddress]) / (1e36))
                .toUint256(); //we divide since we muliplied the price by 1e36 for precision
    }

    function addTotalSharesOfAndRebalance(address staker, uint256 shares)
        external
        override
        onlyExternalCaller
        ensureIsVcaRegistered(staker)
    {
        uint256 oldTotalSharesOf = totalSharesOf[staker];

        totalSharesOf[staker] += shares;

        rebalance(staker, oldTotalSharesOf);
    }

    function subTotalSharesOfAndRebalance(address staker, uint256 shares)
        external
        override
        onlyExternalCaller
        ensureIsVcaRegistered(staker)
    {
        uint256 oldTotalSharesOf = totalSharesOf[staker];
        totalSharesOf[staker] -= shares;

        rebalance(staker, oldTotalSharesOf);
    }

    //the rebalance function recalculates the deductBalances of an user after the total number of shares changes as a result of a stake/unstake
    // @param staker {address} - address of account
    // @param oldTotalSharesOf {uint} - previous number of shares for the account
    function rebalance(address staker, uint256 oldTotalSharesOf) internal {
        for (uint8 i = 0; i < divTokens.length(); i++) {
            int256 tokenInterestEarned = (oldTotalSharesOf * tokenPricePerShare[divTokens.at(i)])
            .toInt256() - deductBalances[staker][divTokens.at(i)];

            deductBalances[staker][divTokens.at(i)] =
                (totalSharesOf[staker] * tokenPricePerShare[divTokens.at(i)]).toInt256() -
                tokenInterestEarned;
        }
    }

    //function that will update the price per share for a dividend token. it is called from within the auction contract as a result of a venture auction bid
    // @param bidderAddress {address} - the address of the bidder
    // @param tokenAddress {address} - the divident token address
    // @param amountBought {uint} - the amount in ETH that was bid in the auction
    function updateTokenPricePerShare(
        address payable bidderAddress,
        address tokenAddress,
        uint256 amountBought
    ) external payable override onlyExternalCaller {
        // uint amountForBidder = amountBought.mul(10526315789473685).div(1e17);
        uint256 amountForOrigin = (amountBought * 5) / 100; //5% fee goes to dev
        uint256 amountForBidder = (amountBought * 10) / 100; //10% is being returned to bidder
        uint256 amountForDivs = amountBought - amountForOrigin - amountForBidder; //remaining is the actual amount that was used to buy the token

        if (tokenAddress != address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)) {
            IERC20Upgradeable(tokenAddress).transfer(
                bidderAddress, //pay the bidder the 10%
                amountForBidder
            );
        } else {
            //if token is ETH we use the transfer function
            bidderAddress.transfer(amountForBidder);
        }

        originWithdrawableTokenAmounts[tokenAddress] += amountForOrigin;

        tokenPricePerShare[tokenAddress] =
            tokenPricePerShare[tokenAddress] + //increase the token price per share with the amount bought divided by the total Vca registered shares
            (amountForDivs * (1e36)) /
            (contracts.stakeManager.getTotalVcaRegisteredShares() + 1e12);
    }

    //add a new dividend token
    // @param tokenAddress {address} - dividend token address
    function addDivToken(address tokenAddress) external override onlyExternalCaller {
        divTokens.add(tokenAddress);
    }

    /** Initialize -------------------------------------------------------------------------------- */
    function initialize(address _manager, address _migrator) public initializer {
        _setupRole(MANAGER_ROLE, _manager);
        _setupRole(MIGRATOR_ROLE, _migrator);

        _setupRole(EXTERNAL_CALLER_ROLE, _manager);
        _setupRole(EXTERNAL_CALLER_ROLE, _migrator);
    }

    function init(
        address _auction,
        address _auctionBidder,
        address _stakeToken,
        address _stakeManager,
        address _stakeMinter,
        address _stakingV1,
        address _stakingV2
    ) public onlyMigrator {
        _setupRole(EXTERNAL_CALLER_ROLE, _auction);
        _setupRole(EXTERNAL_CALLER_ROLE, _auctionBidder);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeToken);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeManager);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeMinter);

        contracts.stakingV1 = IStakingV1(_stakingV1);
        contracts.stakingV2 = IStakingV21(_stakingV2);
        contracts.stakeManager = IStakeManager(_stakeManager);
    }

    function getDeductBalances(address staker, address token) external view returns (int256) {
        return deductBalances[staker][token];
    }

    //calculate the interest earned by an address for a specific dividend token
    // @param accountAddress {address} - address of account
    // @param tokenAddress {address} - address of the dividend token
    function getTokenInterestEarned(address accountAddress, address tokenAddress)
        external
        ensureIsVcaRegistered(accountAddress)
        returns (uint256)
    {
        return getTokenInterestEarnedInternal(accountAddress, tokenAddress);
    }

    function getDivTokens() external view returns (address[] memory) {
        address[] memory divTokenAddresses = new address[](divTokens.length());

        for (uint256 i = 0; i < divTokens.length(); i++) {
            divTokenAddresses[i] = divTokens.at(i);
        }

        return divTokenAddresses;
    }

    function getTotalSharesOf(address account) external view returns (uint256) {
        return totalSharesOf[account];
    }

    function getIsVCARegistered(address staker) external view returns (bool) {
        if (isVcaRegistered[staker] == false) {
            return contracts.stakingV2.getIsVCARegistered(staker);
        }

        return true;
    }

    function getOriginWithdrawableTokenAmount(address tokenAddress)
        external
        view
        returns (uint256)
    {
        return originWithdrawableTokenAmounts[tokenAddress];
    }
}