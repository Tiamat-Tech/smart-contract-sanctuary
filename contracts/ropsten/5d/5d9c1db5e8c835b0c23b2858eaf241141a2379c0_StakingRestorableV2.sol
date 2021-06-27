// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
/** OpenZeppelin Dependencies Upgradeable */
/** OpenZepplin non-upgradeable Swap Token (hex3t) */
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
/** Local Interfaces */
import '../StakingV2.sol';

contract StakingRestorableV2 is StakingV2 {
    using SafeMathUpgradeable for uint256;

    function init(
        address _mainTokenAddress,
        address _auctionAddress,
        address _stakingV1Address,
        uint256 _stepTimestamp,
        uint256 _lastSessionIdV1
    ) external onlyMigrator {
        require(!init_, 'Staking: init is active');
        init_ = true;
        /** Setup */
        _setupRole(EXTERNAL_STAKER_ROLE, _auctionAddress);

        addresses = Addresses({
            mainToken: _mainTokenAddress,
            auction: _auctionAddress,
            subBalances: address(0)
        });

        stakingV1 = IStakingV1(_stakingV1Address);
        stepTimestamp = _stepTimestamp;

        if (startContract == 0) {
            startContract = block.timestamp;
            nextPayoutCall = startContract.add(_stepTimestamp);
        }
        if (_lastSessionIdV1 != 0) {
            lastSessionIdV1 = _lastSessionIdV1;
        }
        if (shareRate == 0) {
            shareRate = 1e18;
        }
    }

    // migration functions
    function setOtherVars(
        uint256 _startTime,
        uint256 _shareRate,
        uint256 _sharesTotalSupply,
        uint256 _nextPayoutCall,
        uint256 _globalPayin,
        uint256 _globalPayout,
        uint256[] calldata _payouts,
        uint256[] calldata _sharesTotalSupplyVec,
        uint256 _lastSessionId
    ) external onlyMigrator {
        startContract = _startTime;
        shareRate = _shareRate;
        sharesTotalSupply = _sharesTotalSupply;
        nextPayoutCall = _nextPayoutCall;
        globalPayin = _globalPayin;
        globalPayout = _globalPayout;
        lastSessionId = _lastSessionId;
        lastSessionIdV1 = _lastSessionId;

        for (uint256 i = 0; i < _payouts.length; i++) {
            payouts.push(
                Payout({payout: _payouts[i], sharesTotalSupply: _sharesTotalSupplyVec[i]})
            );
        }
    }

    function setBasePeriod(uint256 _basePeriod) external onlyMigrator {
        basePeriod = _basePeriod;
    }

    /** TESTING ONLY */
    function setLastSessionId(uint256 _lastSessionId) external onlyMigrator {
        lastSessionIdV1 = _lastSessionId.sub(1);
        lastSessionId = _lastSessionId;
    }

    function setSharesTotalSupply(uint256 _sharesTotalSupply) external onlyMigrator {
        sharesTotalSupply = _sharesTotalSupply;
    }

    function setTotalStakedAmount(uint256 _totalStakedAmount) external onlyMigrator {
        totalStakedAmount = _totalStakedAmount;
    }

    // Used for tests only
    function resetTotalSharesOfAccount() external {
        isVcaRegistered[msg.sender] = false;
        totalVcaRegisteredShares = totalVcaRegisteredShares.sub(totalSharesOf[msg.sender]);
        totalSharesOf[msg.sender] = 0;
    }

    /** No longer needed */
    function setShareRate(uint256 _shareRate) external onlyManager {
        shareRate = _shareRate;
    }

    function addStakedAmount(uint256 _staked) external onlyMigrator {
        totalStakedAmount = totalStakedAmount.add(_staked);
    }

    function addShareTotalSupply(uint256 _shares) external onlyMigrator {
        sharesTotalSupply = sharesTotalSupply.add(_shares);
    }
}