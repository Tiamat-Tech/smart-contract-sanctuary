// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;
import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol';

import '../libs/AxionSafeCast.sol';
import '../interfaces/IBpd.sol';
import '../abstracts/Migrateable.sol';
import '../abstracts/ExternallyCallable.sol';

contract BPD is IBpd, Migrateable, ExternallyCallable {
    using AxionSafeCast for uint256;
    using SafeCastUpgradeable for uint256;

    struct Settings {
        uint32 secondsInDay; // 24h * 60 * 60
        uint64 contractStartTimestamp; //time the contract started
        uint32 bpdDayRange; //350 days, time of the first BPD
    }

    uint48[5] internal bpdShares;
    Settings internal settings;

    function addBpdShares(
        uint256 shares,
        uint256 start,
        uint256 stakingDays
    ) external override onlyExternalCaller {
        uint256 end = start + (stakingDays * settings.secondsInDay);

        uint256[2] memory bpdInterval = getBpdInterval(start, end);
        uint48[5] memory _bpdShares = bpdShares; // one read (SLOAD)

        uint48 shares0Dp = (shares / 1e18).toUint48();

        for (uint256 i = bpdInterval[0]; i < bpdInterval[1]; i++) {
            _bpdShares[i] += shares0Dp; // we only do integer shares, no decimals
        }

        bpdShares = _bpdShares; // one write (SSTORE)
    }

    function addBpdMaxShares(
        uint256 oldShares,
        uint256 oldStart,
        uint256 oldEnd,
        uint256 newShares,
        uint256 newStart,
        uint256 newEnd
    ) external override onlyExternalCaller {
        uint256[2] memory oldBpdInterval = getBpdInterval(oldStart, oldEnd);
        uint256[2] memory newBpdInterval = getBpdInterval(newStart, newEnd);

        uint48[5] memory _bpdShares = bpdShares; // one read (SLOAD)

        uint48 newShares0Dp = (newShares / 1e18).toUint48();
        uint48 oldShares0Dp = (oldShares / 1e18).toUint48();

        for (uint256 i = oldBpdInterval[0]; i < newBpdInterval[1]; i++) {
            if (oldBpdInterval[1] > i) {
                _bpdShares[i] += newShares0Dp - oldShares0Dp; // we only do integer shares, no decimals
            } else {
                _bpdShares[i] += newShares0Dp; // we only do integer shares, no decimals
            }
        }

        bpdShares = _bpdShares; // one write
    }

    function getBpdAmount(
        uint256 shares,
        uint256 start,
        uint256 end
    ) external view override returns (uint256) {
        uint256 bpdAmount;
        uint8[5] memory bpdPools = getBpdPools();
        uint256[2] memory bpdInterval = getBpdInterval(start, end);

        for (uint256 i = bpdInterval[0]; i < bpdInterval[1]; i++) {
            bpdAmount += (shares / bpdShares[i]) * (uint256(bpdPools[i]) * 1e8); // x 1e8 since we have one decimal
        }

        return bpdAmount; // return with 18 decimals
    }

    function getBpdPools() internal pure returns (uint8[5] memory) {
        return [50, 75, 100, 125, 150];
    }

    function getBpdInterval(uint256 start, uint256 end) internal view returns (uint256[2] memory) {
        uint256[2] memory bpdInterval;
        uint256 denom = settings.secondsInDay * settings.bpdDayRange;

        bpdInterval[0] = MathUpgradeable.min(5, (start - settings.contractStartTimestamp) / denom); // (start - t0) // 350

        uint256 bpdEnd = bpdInterval[0] + (end - start) / denom;

        bpdInterval[1] = MathUpgradeable.min(bpdEnd, 5); // bpd_first + nx350

        return bpdInterval;
    }

    function initialize(address _migrator, address _stakeManager) external initializer {
        _setupRole(MIGRATOR_ROLE, _migrator);
        _setupRole(EXTERNAL_CALLER_ROLE, _stakeManager);
    }

    function setBpdShares(uint48[5] calldata shares) external onlyMigrator {
        bpdShares = shares;
    }

    function setSettings(
        uint32 _secondsInDay,
        uint64 _contractStartTimestamp,
        uint32 _bpdDayRange
    ) external onlyMigrator {
        if (_secondsInDay != 0) settings.secondsInDay = _secondsInDay;
        if (_contractStartTimestamp != 0) settings.contractStartTimestamp = _contractStartTimestamp;
        if (_bpdDayRange != 0) settings.bpdDayRange = _bpdDayRange;
    }

    function findBpdEligible(uint256 start, uint256 end) external view returns (uint256[2] memory) {
        return getBpdInterval(start, end);
    }

    function getBpdShares() external view returns (uint48[5] memory) {
        return bpdShares;
    }
}