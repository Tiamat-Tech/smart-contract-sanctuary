// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

import "./pancake-swap/interfaces/IPancakePair.sol";
import "./pancake-swap/interfaces/IPancakeRouter02.sol";
import "./pancake-swap/interfaces/IPancakeFactory.sol";

import "./interfaces/IAsset.sol";
import "./interfaces/IStaking.sol";

import "./lib/AssetLib.sol";

contract Staking is ReentrancyGuard, Context, IStaking {
    struct PoolInfo {
        uint256[3] numOfSharesNow;
        /*
        incomeInfo
        0 - num of shares in pool for _TIME_DURATIONS[0]
        1 - num of shares in pool for _TIME_DURATIONS[1]
        2 - num of shares in pool for _TIME_DURATIONS[2]
        3 - bnb amount in pool for _TIME_DURATIONS[0]
        4 - bnb amount in pool for _TIME_DURATIONS[1]
        5 - bnb amount in pool for _TIME_DURATIONS[2]
         */
        uint256[][6] incomeInfo;
        uint256 bagToDistribute;
        uint256 amountOfPenalties;
    }

    struct StakeInfo {
        address staker;
        uint256 lastIncomeIndex;
        address tokenStaked;
        uint256 amountStaked;
        uint256 timestampStakeStart;
        uint8 timeIntervalIndex;
        bool isClaimed;
    }

    // public variables
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(address => PoolInfo) public poolInfo;
    mapping(address => StakeInfo[]) public stakeInfo;

    address public immutable YDR_TOKEN;
    address public immutable FACTORY;
    address public immutable DEX_ROUTER;
    address public immutable DEX_FACTORY;
    address public ydrLpToken;

    uint256 public treasuryAmount;

    address[] public tokensToEnter;

    // internal variables
    mapping(address => bool) internal _isAllowedToken;

    // private variables
    uint256[3] private _TIME_DURATIONS = [2592000, 7776000, 31104000];
    // percentages for asset - [0-2] and for assetLP - [3-5]
    uint256[6] private _POOL_PERCENTAGES = [80, 240, 480, 120, 360, 720];
    // percentages for ydr - [0-2] and for ydrLP - [3-5]
    uint256[6] private _YDR_POOL_PERCENTAGES = [300, 900, 1800, 400, 1200, 2400];
    // percentages for penalties ydr - [0-2] and for ydrLP - [3-5]
    uint256[6] private _YDR_POOL_PENALTY_PERCENTAGES = [375, 1125, 2250, 500, 1500, 3000];
    address private immutable weth;

    // modifiers
    modifier onlyFactory {
        require(_msgSender() == FACTORY, "Access error");
        _;
    }
    modifier onlyManagerOrAdmin {
        address sender = _msgSender();
        address factory = FACTORY;
        require(
            AccessControl(factory).hasRole(MANAGER_ROLE, sender) ||
                AccessControl(factory).hasRole(0x00, sender),
            "Access error"
        );
        _;
    }

    constructor(
        address ydrToken,
        address factory,
        address dexRouter,
        address dexFactory
    ) {
        YDR_TOKEN = ydrToken;
        FACTORY = factory;
        DEX_ROUTER = dexRouter;
        DEX_FACTORY = dexFactory;
        weth = IPancakeRouter02(dexRouter).WETH();

        _isAllowedToken[ydrToken] = true;
        tokensToEnter.push(ydrToken);
    }

    receive() external payable {
        address sender = _msgSender();
        require(
            _isAllowedTokenCheck(sender) || sender == weth || sender == DEX_ROUTER,
            "Access error"
        );
    }

    function stakeStart(
        address token,
        uint256 amount,
        uint8 timeIntervalIndex
    ) external override {
        require(token != address(0) && amount > 0 && timeIntervalIndex < 3, "Input error");
        require(_isAllowedTokenCheck(token), "Wrong token");

        address sender = _msgSender();
        AssetLib.safeTransferFrom(token, sender, amount);

        StakeInfo memory stake;
        stake.staker = sender;
        stake.lastIncomeIndex = poolInfo[token].incomeInfo[timeIntervalIndex].length;
        stake.tokenStaked = token;
        stake.amountStaked = amount;
        stake.timeIntervalIndex = timeIntervalIndex;
        stake.timestampStakeStart = block.timestamp;
        stakeInfo[sender].push(stake);

        poolInfo[token].numOfSharesNow[timeIntervalIndex] += amount;
    }

    function stakeEnd(uint256 stakeIndex) external override {
        address sender = _msgSender();
        require(stakeIndex < stakeInfo[sender].length, "Input error");
        require(stakeInfo[sender][stakeIndex].isClaimed == false, "Already claimed");

        uint256 timeIntervalIndex = stakeInfo[sender][stakeIndex].timeIntervalIndex;
        address tokenStaked = stakeInfo[sender][stakeIndex].tokenStaked;
        uint256 amountStaked = stakeInfo[sender][stakeIndex].amountStaked;

        // calculate and send dividends (no penalty)
        (uint256 amountOfDividends, ) =
            _calculateDividends(
                poolInfo[tokenStaked],
                timeIntervalIndex,
                amountStaked,
                stakeInfo[sender][stakeIndex].lastIncomeIndex,
                0
            );
        AssetLib.safeTransfer(address(0), sender, amountOfDividends);

        // send stake token back (may be penalty)
        if (
            block.timestamp >=
            stakeInfo[sender][stakeIndex].timestampStakeStart + _TIME_DURATIONS[timeIntervalIndex]
        ) {
            // no penalty
            AssetLib.safeTransfer(tokenStaked, sender, amountStaked);
        } else {
            // penalty 25%
            uint256 penalty = (amountStaked * 2500) / 1e4;
            _proceedPenalty(tokenStaked, penalty);
            AssetLib.safeTransfer(tokenStaked, sender, amountStaked - penalty);
        }

        stakeInfo[sender][stakeIndex].isClaimed = true;
    }

    function claimDividends(uint256 stakeIndex, uint256 maxDepth) external override {
        address sender = _msgSender();
        require(stakeIndex < stakeInfo[sender].length, "Input error");
        require(stakeInfo[sender][stakeIndex].isClaimed == false, "Already claimed");

        address tokenStaked = stakeInfo[sender][stakeIndex].tokenStaked;
        uint256 amountStaked = stakeInfo[sender][stakeIndex].amountStaked;

        // calculate and send dividends (no penalty)
        (uint256 amountOfDividends, uint256 newIncomeIndex) =
            _calculateDividends(
                poolInfo[tokenStaked],
                stakeInfo[sender][stakeIndex].timeIntervalIndex,
                amountStaked,
                stakeInfo[sender][stakeIndex].lastIncomeIndex,
                maxDepth
            );
        stakeInfo[sender][stakeIndex].lastIncomeIndex = newIncomeIndex;

        AssetLib.safeTransfer(address(0), sender, amountOfDividends);
    }

    function createPool(address token) external override onlyFactory {
        _isAllowedToken[token] = true;
        tokensToEnter.push(token);
    }

    function inputBnb() external payable override {
        require(_isAllowedToken[_msgSender()] == true, "Not asset");
        _inputBnb(_msgSender(), msg.value);
    }

    function treasuryWithdraw() external override onlyManagerOrAdmin {
        uint256 treasuryAmountOld = treasuryAmount;
        treasuryAmount = 0;
        AssetLib.safeTransfer(address(0), _msgSender(), treasuryAmountOld);
    }

    function getNumOfSharesNow(address token, uint8 timeIntervalIndex)
        external
        view
        returns (uint256)
    {
        require(token != address(0) && timeIntervalIndex < 3, "Input error");
        return poolInfo[token].numOfSharesNow[timeIntervalIndex];
    }

    function getIncomeLen(address token, uint8 timeIntervalIndex) external view returns (uint256) {
        require(token != address(0) && timeIntervalIndex < 3, "Input error");
        return poolInfo[token].incomeInfo[timeIntervalIndex].length;
    }

    function getIncomeShares(
        address token,
        uint8 timeIntervalIndex,
        uint256 index
    ) external view returns (uint256) {
        require(token != address(0) && timeIntervalIndex < 3, "Input error");
        uint256 len = poolInfo[token].incomeInfo[timeIntervalIndex].length;
        require(index < len, "Input error 2");
        return poolInfo[token].incomeInfo[timeIntervalIndex][index];
    }

    function getIncomeAmounts(
        address token,
        uint8 timeIntervalIndex,
        uint256 index
    ) external view returns (uint256) {
        require(token != address(0) && timeIntervalIndex < 3, "Input error");
        uint256 len = poolInfo[token].incomeInfo[timeIntervalIndex].length;
        require(index < len, "Input error 2");
        return poolInfo[token].incomeInfo[timeIntervalIndex + 3][index];
    }

    function getBagToDistribute(address token) external view returns (uint256) {
        require(token != address(0), "Input error");
        return poolInfo[token].bagToDistribute;
    }

    function getAmountOfPenalties(address token) external view returns (uint256) {
        require(token != address(0), "Input error");
        return poolInfo[token].amountOfPenalties;
    }

    function getStakeInfoLen(address user) external view returns (uint256) {
        require(user != address(0), "Input error");
        return stakeInfo[user].length;
    }

    function tokensToEnterLen() external view returns(uint256) {
        return tokensToEnter.length;
    }

    function amountOfDIvidendsToUser(address user, uint256 stakeIndex, uint256 maxDepth) external view returns(uint256) {
        require(user != address(0), "Input error");
        uint256 len = stakeInfo[user].length;
        require(stakeIndex < len, "Input error");
        (uint256 dividends,) = _calculateDividends(
            poolInfo[stakeInfo[user][stakeIndex].tokenStaked],
            stakeInfo[user][stakeIndex].timestampStakeStart,
            stakeInfo[user][stakeIndex].amountStaked,
            stakeInfo[user][stakeIndex].lastIncomeIndex,
            maxDepth
        );
        return dividends;
    }

    function _calculateDividends(
        PoolInfo storage pool,
        uint256 timeIntervalIndex,
        uint256 amount,
        uint256 indexFrom,
        uint256 maxDepth
    ) private view returns (uint256, uint256) {
        uint256 lenMax = pool.incomeInfo[timeIntervalIndex].length;
        uint256 indexTo;
        if (maxDepth == 0 || indexFrom + maxDepth > lenMax) {
            indexTo = lenMax;
        } else {
            indexTo = indexFrom + maxDepth;
        }

        uint256 totalDividends;
        for (uint256 i = indexFrom; i < indexTo; ++i) {
            uint256 incomeBnb = pool.incomeInfo[timeIntervalIndex + 3][i];
            uint256 totalShares = pool.incomeInfo[timeIntervalIndex][i];
            totalDividends += (incomeBnb * amount) / totalShares;
        }

        return (totalDividends, indexTo);
    }

    function _inputBnb(address token, uint256 amount) private {
        require(amount > 0, "Amount error");
        address ydrToken = YDR_TOKEN;
        address _ydrLpToken = ydrLpToken;
        address _weth = weth;
        address dexFactory = DEX_FACTORY;
        if (_ydrLpToken == address(0)) {
            _ydrLpToken = IPancakeFactory(dexFactory).getPair(ydrToken, _weth);
            if (_ydrLpToken != address(0)) {
                ydrLpToken = _ydrLpToken;
            }
        }

        address tokenLp = IPancakeFactory(dexFactory).getPair(token, _weth);
        require(_getTokenOutOfLp(token) == token, "Internal error lp");

        uint256 inBagNow = poolInfo[token].bagToDistribute;
        if (inBagNow > 0) {
            amount += inBagNow;
            poolInfo[token].bagToDistribute = 0;
            inBagNow = 0;
        }

        uint256 restAmount = amount;
        if (token != ydrToken && token != _ydrLpToken) {
            /* percentages = _POOL_PERCENTAGES;
            uint256 amountToTokenAndLp =
                _calculcateAmountFor6Percentages(amount, percentages); */
            restAmount = _inputInTokenAndLpPools(
                token,
                tokenLp,
                amount,
                restAmount,
                _POOL_PERCENTAGES
            );

            /* percentages = _YDR_POOL_PERCENTAGES;
            amountToTokenAndLp = _calculcateAmountFor6Percentages(amount, percentages); */
            restAmount = _inputInTokenAndLpPools(
                ydrToken,
                _ydrLpToken,
                amount,
                restAmount,
                _YDR_POOL_PERCENTAGES
            );
        } else {
            // if token == ydrToken || token == ydrLpToken
            /* percentages = _YDR_POOL_PENALTY_PERCENTAGES;
            uint256 amountToTokenAndLp =
                _calculcateAmountFor6Percentages(amount, percentages); */
            restAmount = _inputInTokenAndLpPools(
                ydrToken,
                _ydrLpToken,
                amount,
                restAmount,
                _YDR_POOL_PENALTY_PERCENTAGES
            );
        }

        uint256 calculatedAmountToTreasury = amount * 1000 / 1e4;
        if (calculatedAmountToTreasury > restAmount) {
            calculatedAmountToTreasury = restAmount;
            restAmount = 0;
        } else {
            restAmount -= calculatedAmountToTreasury;
        }
        treasuryAmount += calculatedAmountToTreasury;

        if (restAmount > 0) {
            inBagNow += restAmount;
            poolInfo[token].bagToDistribute = inBagNow;
        }
    }

    function _proceedPenalty(address token, uint256 amount) private {
        address goodToken = _getTokenOutOfLp(token);

        uint256 amountOfPenalties = poolInfo[goodToken].amountOfPenalties;
        if (amountOfPenalties > 0 && token == goodToken) {
            amount += amountOfPenalties;
            poolInfo[goodToken].amountOfPenalties = 0;
            amountOfPenalties = 0;
        }
        (uint256 bnbAmount, bool isValid) = _withdrawTokenToBnb(token, goodToken, amount, (token != goodToken));

        if (isValid == true) {
            poolInfo[goodToken].bagToDistribute += bnbAmount;
        } else {
            // can not be lp token here
            amountOfPenalties += amount;
            poolInfo[goodToken].amountOfPenalties = amountOfPenalties;
        }
    }

    function _getTokenOutOfLp(address token) private view returns (address) {
        address token0;
        address token1;
        try IPancakePair(token).token0() returns (address _token0) {
            token0 = _token0;
        } catch (bytes memory) {
            return token;
        }
        try IPancakePair(token).token1() returns (address _token1) {
            token1 = _token1;
        } catch (bytes memory) {
            return token;
        }

        if (token0 == weth) {
            return token1;
        } else {
            return token0;
        }
    }

    function _withdrawTokenToBnb(
        address token,
        address goodToken,
        uint256 amount,
        bool isLp
    ) private returns(uint256 result, bool isValid) {
        if (token != goodToken) {
            address dexRouter = DEX_ROUTER;
            AssetLib.checkAllowance(token, dexRouter, amount);
            (uint256 amountToken, uint256 amountETH) =
                IPancakeRouter02(dexRouter).removeLiquidityETH(
                    goodToken,
                    amount,
                    0,
                    0,
                    address(this),
                    block.timestamp
                );
            result += amountETH;
            (uint256 result2,) = _withdrawTokenToBnb(goodToken, goodToken, amountToken, false);
            result += result2;
        } else {
            address pair = IPancakeFactory(DEX_FACTORY).getPair(weth, token);
            if (pair == address(0)) {
                return (0, false);
            }
            address dexRouter = DEX_ROUTER;
            AssetLib.checkAllowance(token, dexRouter, amount);
            address[] memory path = new address[](2);
            path[0] = token;
            path[1] = weth;
            uint256[] memory amounts = IPancakeRouter02(dexRouter).swapExactTokensForETH(
                amount,
                0,
                path,
                address(this),
                block.timestamp
            );
            result += amounts[1];
        }
        isValid = true;
    }

    function _inputInTokenAndLpPools(
        address token,
        address tokenLp,
        uint256 amount,
        uint256 restAmount,
        uint256[6] memory percentages
    ) private returns (uint256) {
        // input bnb to asset
        restAmount -= _inputInPool(token, amount, [percentages[0], percentages[1], percentages[2]]);

        // input bnb to assetLp
        if (tokenLp != address(0)) {
            restAmount -= _inputInPool(tokenLp, amount, [percentages[3], percentages[4], percentages[5]]);
        }

        return restAmount;
    }

    function _inputInPool(
        address token,
        uint256 amount,
        uint256[3] memory percentages
    ) private returns(uint256) {
        PoolInfo storage pool = poolInfo[token];

        uint256 amountTo0 = (amount * percentages[0]) / 1e4;
        uint256 amountTo1 = (amount * percentages[1]) / 1e4;
        uint256 amountTo2 = (amount * percentages[2]) / 1e4;

        uint256 amountDistributed;

        uint256 numOfSharesNow = pool.numOfSharesNow[0];
        if (numOfSharesNow != 0) {
            pool.incomeInfo[0].push(numOfSharesNow);
            pool.incomeInfo[3].push(amountTo0);
            amountDistributed += amountTo0;
        }

        numOfSharesNow = pool.numOfSharesNow[1];
        if (numOfSharesNow != 0) {
            pool.incomeInfo[1].push(numOfSharesNow);
            pool.incomeInfo[4].push(amountTo1);
            amountDistributed += amountTo1;
        }

        numOfSharesNow = pool.numOfSharesNow[2];
        if (numOfSharesNow != 0) {
            pool.incomeInfo[2].push(numOfSharesNow);
            pool.incomeInfo[5].push(amountTo2);
            amountDistributed += amountTo2;
        }

        return amountDistributed;
    }

    function _isAllowedTokenCheck(address token) private returns (bool) {
        if (_isAllowedToken[token] == true) {
            return true;
        } else {
            address token0;
            try IPancakePair(token).token0() returns (address _token0) {
                token0 = _token0;
            } catch (bytes memory) {
                return false;
            }

            address token1;
            try IPancakePair(token).token1() returns (address _token1) {
                token1 = _token1;
            } catch (bytes memory) {
                return false;
            }

            address goodPair = IPancakeFactory(DEX_FACTORY).getPair(token0, token1);
            if (goodPair != token) {
                return false;
            }

            address _weth = weth;
            if (token0 != _weth && token1 != _weth) {
                return false;
            }

            if (_isAllowedToken[token0] == false && _isAllowedToken[token1] == false) {
                return false;
            }

            _isAllowedToken[token] = true;
            return true;
        }
    }
}