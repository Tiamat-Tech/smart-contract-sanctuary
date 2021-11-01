// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "./libs/SafeERC20.sol";

interface IConvexBooster {
    function liquidate(
        uint256 _convexPid,
        int128 _curveCoinId,
        address _user,
        uint256 _amount
    ) external returns (address, uint256);

    function depositFor(
        uint256 _convexPid,
        uint256 _amount,
        address _user
    ) external returns (bool);

    function withdrawFor(
        uint256 _convexPid,
        uint256 _amount,
        address _user
    ) external returns (bool);

    function poolInfo(uint256 _convexPid)
        external
        view
        returns (
            uint256 originConvexPid,
            address curveSwapAddress,
            address lpToken,
            address originCrvRewards,
            address originStash,
            address virtualBalance,
            address rewardPool,
            address stashToken,
            uint256 swapType,
            uint256 swapCoins
        );
}

interface ICompoundBooster {
    function liquidate(
        bytes32 _lendingId,
        uint256 _lendingAmount,
        uint256 _interestValue
    ) external payable returns (address);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            address lpToken,
            address rewardPool,
            address rewardLendflareTokenPool,
            address treasuryFund,
            address rewardInterestPool,
            bool isErc20,
            bool shutdown
        );

    function getLendingInfos(bytes32 _lendingId)
        external
        view
        returns (address payable, address);

    function borrow(
        uint256 _pid,
        bytes32 _lendingId,
        address _user,
        uint256 _amount,
        uint256 _collateralAmount,
        uint256 _borrowNumbers
    ) external;

    function repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _interestValue
    ) external payable;

    function repayBorrowErc20(
        bytes32 _lendingId,
        address _user,
        uint256 _amount,
        uint256 _interestValue
    ) external;

    function getBorrowRatePerBlock(uint256 _pid)
        external
        view
        returns (uint256);

    function getExchangeRateStored(uint256 _pid)
        external
        view
        returns (uint256);

    function getBlocksPerYears(uint256 _pid, bool isSplit)
        external
        view
        returns (uint256);

    function getUtilizationRate(uint256 _pid) external view returns (uint256);

    function getCollateralFactorMantissa(uint256 _pid)
        external
        view
        returns (uint256);
}

interface ICurveSwap {
    // function get_virtual_price() external view returns (uint256);

    // lp to token 68900637075889600000000, 2
    function calc_withdraw_one_coin(uint256 _tokenAmount, int128 _tokenId)
        external
        view
        returns (uint256);

    // token to lp params: [0,0,70173920000], false
    /* function calc_token_amount(uint256[] memory amounts, bool deposit)
        external
        view
        returns (uint256); */
}

interface ILiquidateSponsor {
    function addSponsor(bytes32 _lendingId, address _user) external payable;

    function requestSponsor(bytes32 _lendingId) external;

    function payFee(
        bytes32 _lendingId,
        address _user,
        uint256 _expendGas
    ) external;
}

contract ConvexCompoundGauge {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public convexBooster;
    address public compoundBooster;
    address public liquidateSponsor;

    uint256 public liquidateThresholdBlockNumbers;

    enum UserLendingState {
        LENDING,
        EXPIRED,
        LIQUIDATED
    }

    struct PoolInfo {
        uint256 convexPid;
        uint256[] supportPids;
        int128[] curveCoinIds;
        uint256 lendingThreshold;
        uint256 liquidateThreshold;
        uint256 borrowIndex;
    }

    struct UserLending {
        bytes32 lendingId;
        uint256 token0;
        uint256 token0Price;
        uint256 lendingAmount;
        uint256 supportPid;
        int128 curveCoinId;
        uint256 interestValue;
        uint256 borrowNumbers;
        uint256 borrowBlocksLimit;
    }

    struct LendingInfo {
        address user;
        uint256 pid;
        uint256 userLendingId;
        uint256 borrowIndex;
        uint256 startedBlock;
        uint256 utilizationRate;
        uint256 compoundRatePerBlock;
        UserLendingState state;
    }

    struct BorrowInfo {
        uint256 borrowAmount;
        uint256 supplyAmount;
    }

    struct Statistic {
        uint256 totalCollateral;
        uint256 totalBorrow;
        uint256 recentRepayAt;
    }

    struct LendingParams {
        uint256 lendingAmount;
        uint256 collateralAmount;
        uint256 interestAmount;
        uint256 borrowRate;
        uint256 utilizationRate;
        uint256 compoundRatePerBlock;
        address lpToken;
        uint256 token0Price;
    }

    PoolInfo[] public poolInfo;

    // user address => container
    mapping(address => UserLending[]) public userLendings;
    // lending id => user address
    mapping(bytes32 => LendingInfo) public lendings;
    // pool id => (borrowIndex => user lendingId)
    mapping(uint256 => mapping(uint256 => bytes32)) public poolLending;
    mapping(bytes32 => BorrowInfo) public borrowInfos;
    mapping(bytes32 => Statistic) public myStatistics;
    // number => block numbers
    mapping(uint256 => uint256) public borrowNumberLimit;

    event Borrow(
        bytes32 indexed lendingId,
        address user,
        uint256 token0,
        uint256 token0Price,
        uint256 lendingAmount,
        uint256 borrowBlocksLimit,
        UserLendingState state
    );

    event RepayBorrow(
        bytes32 indexed lendingId,
        address user,
        UserLendingState state
    );

    event Liquidate(
        bytes32 indexed lendingId,
        address user,
        uint256 liquidateAmount,
        uint256 gasSpent,
        UserLendingState state
    );

    function init(
        address _liquidateSponsor,
        address _convexBooster,
        address _compoundBooster
    ) public {
        liquidateSponsor = _liquidateSponsor;
        convexBooster = _convexBooster;
        compoundBooster = _compoundBooster;

        borrowNumberLimit[4] = 16;
        borrowNumberLimit[6] = 64;
        borrowNumberLimit[19] = 524288;
        borrowNumberLimit[20] = 1048576;
        borrowNumberLimit[21] = 2097152;

        liquidateThresholdBlockNumbers = 20;
    }

    function borrow(
        uint256 _pid,
        uint256 _token0,
        uint256 _borrowNumber,
        uint256 _supportPid
    ) public payable {
        require(borrowNumberLimit[_borrowNumber] != 0, "!borrowNumberLimit");
        require(msg.value == 0.1 ether, "!liquidateSponsor");

        _borrow(_pid, _supportPid, _borrowNumber, _token0);
    }

    function _getCurveInfo(
        uint256 _convexPid,
        int128 _curveCoinId,
        uint256 _token0
    ) internal view returns (address lpToken, uint256 token0Price) {
        address curveSwapAddress;
        (, curveSwapAddress, lpToken, , , , , , , ) = IConvexBooster(
            convexBooster
        ).poolInfo(_convexPid);
        token0Price = ICurveSwap(curveSwapAddress).calc_withdraw_one_coin(
            _token0,
            _curveCoinId
        );
    }

    function _borrow(
        uint256 _pid,
        uint256 _supportPid,
        uint256 _borrowNumber,
        uint256 _token0
    ) internal returns (LendingParams memory) {
        PoolInfo storage pool = poolInfo[_pid];

        pool.borrowIndex++;

        bytes32 lendingId = generateId(
            msg.sender,
            _pid,
            pool.borrowIndex + block.number
        );

        LendingParams memory lendingParams = getLendingInfo(
            _token0,
            pool.convexPid,
            pool.curveCoinIds[_supportPid],
            pool.supportPids[_supportPid],
            pool.lendingThreshold,
            pool.liquidateThreshold,
            _borrowNumber
        );

        IERC20(lendingParams.lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _token0
        );

        IERC20(lendingParams.lpToken).safeApprove(convexBooster, 0);
        IERC20(lendingParams.lpToken).safeApprove(convexBooster, _token0);

        ICompoundBooster(compoundBooster).borrow(
            pool.supportPids[_supportPid],
            lendingId,
            msg.sender,
            lendingParams.lendingAmount,
            lendingParams.collateralAmount,
            _borrowNumber
        );

        IConvexBooster(convexBooster).depositFor(
            pool.convexPid,
            _token0,
            msg.sender
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(_pid, pool.supportPids[_supportPid], address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.add(
            lendingParams.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.add(
            lendingParams.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(_pid, pool.supportPids[_supportPid], msg.sender)
        ];

        statistic.totalCollateral = statistic.totalCollateral.add(_token0);
        statistic.totalBorrow = statistic.totalBorrow.add(
            lendingParams.lendingAmount
        );

        userLendings[msg.sender].push(
            UserLending({
                lendingId: lendingId,
                token0: _token0,
                token0Price: lendingParams.token0Price,
                lendingAmount: lendingParams.lendingAmount,
                supportPid: pool.supportPids[_supportPid],
                curveCoinId: pool.curveCoinIds[_supportPid],
                interestValue: lendingParams.interestAmount,
                borrowNumbers: _borrowNumber,
                borrowBlocksLimit: borrowNumberLimit[_borrowNumber]
            })
        );

        lendings[lendingId] = LendingInfo({
            user: msg.sender,
            pid: _pid,
            borrowIndex: pool.borrowIndex,
            userLendingId: userLendings[msg.sender].length - 1,
            startedBlock: block.number,
            utilizationRate: lendingParams.utilizationRate,
            compoundRatePerBlock: lendingParams.compoundRatePerBlock,
            state: UserLendingState.LENDING
        });

        poolLending[_pid][pool.borrowIndex] = lendingId;

        ILiquidateSponsor(liquidateSponsor).addSponsor{value: msg.value}(
            lendingId,
            msg.sender
        );

        emit Borrow(
            lendingId,
            msg.sender,
            _token0,
            lendingParams.token0Price,
            lendingParams.lendingAmount,
            borrowNumberLimit[_borrowNumber],
            UserLendingState.LENDING
        );
    }

    function _repayBorrow(
        bytes32 _lendingId,
        uint256 _amount,
        bool isErc20
    ) internal {
        LendingInfo storage lendingInfo = lendings[_lendingId];

        require(lendingInfo.startedBlock > 0, "!startedBlock");

        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];
        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        require(
            block.number <=
                lendingInfo.startedBlock.add(userLending.borrowBlocksLimit),
            "Expired"
        );

        uint256 payAmount = userLending.lendingAmount.add(
            userLending.interestValue
        );
        uint256 maxAmount = payAmount.add(payAmount.mul(5).div(1000));

        require(
            _amount >= payAmount && _amount <= maxAmount,
            "amount range error"
        );

        lendingInfo.state = UserLendingState.EXPIRED;

        IConvexBooster(convexBooster).withdrawFor(
            pool.convexPid,
            userLending.token0,
            lendingInfo.user
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );
        statistic.recentRepayAt = block.timestamp;

        if (isErc20) {
            (
                address payable proxyUser,
                address underlyToken
            ) = ICompoundBooster(compoundBooster).getLendingInfos(
                    userLending.lendingId
                );

            IERC20(underlyToken).safeTransferFrom(
                msg.sender,
                proxyUser,
                _amount
            );

            ICompoundBooster(compoundBooster).repayBorrowErc20(
                userLending.lendingId,
                lendingInfo.user,
                _amount,
                userLending.interestValue
            );
        } else {
            ICompoundBooster(compoundBooster).repayBorrow{value: _amount}(
                userLending.lendingId,
                lendingInfo.user,
                userLending.interestValue
            );
        }

        ILiquidateSponsor(liquidateSponsor).requestSponsor(
            userLending.lendingId
        );

        emit RepayBorrow(
            userLending.lendingId,
            lendingInfo.user,
            lendingInfo.state
        );
    }

    function repayBorrow(bytes32 _lendingId) public payable {
        _repayBorrow(_lendingId, msg.value, false);
    }

    function repayBorrow(bytes32 _lendingId, uint256 _amount) public {
        _repayBorrow(_lendingId, _amount, true);
    }

    function liquidate(bytes32 _lendingId) public {
        uint256 gasStart = gasleft();
        LendingInfo storage lendingInfo = lendings[_lendingId];

        require(lendingInfo.startedBlock > 0, "!startedBlock");

        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        require(
            lendingInfo.startedBlock.add(userLending.borrowNumbers).sub(
                liquidateThresholdBlockNumbers
            ) < block.number,
            "!borrowNumbers"
        );

        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        lendingInfo.state = UserLendingState.LIQUIDATED;

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );

        (address payable proxyUser, ) = ICompoundBooster(compoundBooster)
            .getLendingInfos(userLending.lendingId);

        (address underlyToken, uint256 liquidateAmount) = IConvexBooster(
            convexBooster
        ).liquidate(
                pool.convexPid,
                userLending.curveCoinId,
                lendingInfo.user,
                userLending.token0
            );

        if (underlyToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            ICompoundBooster(compoundBooster).liquidate{value: liquidateAmount}(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.interestValue
            );
        } else {
            IERC20(underlyToken).safeTransfer(proxyUser, liquidateAmount);

            ICompoundBooster(compoundBooster).liquidate(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.interestValue
            );
        }

        uint256 gasSpent = (21000 + gasStart - gasleft()).mul(tx.gasprice);

        ILiquidateSponsor(liquidateSponsor).payFee(
            userLending.lendingId,
            msg.sender,
            gasSpent
        );

        emit Liquidate(
            userLending.lendingId,
            lendingInfo.user,
            liquidateAmount,
            gasSpent,
            lendingInfo.state
        );
    }

    function setBorrowNumberLimit(uint256 _number, uint256 _blockNumbers)
        public
    {
        borrowNumberLimit[_number] = _blockNumbers;
    }

    receive() external payable {}

    function addPool(
        uint256 _convexPid,
        uint256[] memory _supportPids,
        int128[] memory _curveCoinIds,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold
    ) public {
        poolInfo.push(
            PoolInfo({
                convexPid: _convexPid,
                supportPids: _supportPids,
                curveCoinIds: _curveCoinIds,
                lendingThreshold: _lendingThreshold,
                liquidateThreshold: _liquidateThreshold,
                borrowIndex: 0
            })
        );
    }

    function setLiquidateThresholdBlockNumbers(uint256 _blockNumbers) public {
        liquidateThresholdBlockNumbers = _blockNumbers;
    }

    /* function toBytes16(uint256 x) internal pure returns (bytes16 b) {
        return bytes16(bytes32(x));
    } */

    function generateId(
        address x,
        uint256 y,
        uint256 z
    ) public pure returns (bytes32) {
        /* return toBytes16(uint256(keccak256(abi.encodePacked(x, y, z)))); */
        return keccak256(abi.encodePacked(x, y, z));
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function cursor(
        uint256 _pid,
        uint256 _offset,
        uint256 _size
    ) public view returns (bytes32[] memory, uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 size = _offset + _size > pool.borrowIndex
            ? pool.borrowIndex - _offset
            : _size;
        uint256 index;

        bytes32[] memory userLendingIds = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            bytes32 userLendingId = poolLending[_pid][_offset + i];

            userLendingIds[index] = userLendingId;
            index++;
        }

        return (userLendingIds, pool.borrowIndex);
    }

    function calculateRepayAmount(bytes32 _lendingId)
        public
        view
        returns (uint256)
    {
        LendingInfo storage lendingInfo = lendings[_lendingId];
        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        if (lendingInfo.state == UserLendingState.LIQUIDATED) return 0;

        return userLending.lendingAmount.add(userLending.interestValue);
    }

    function getPoolSupportPids(uint256 _pid)
        public
        view
        returns (uint256[] memory)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.supportPids;
    }

    function getCurveCoinId(uint256 _pid, uint256 _supportPid)
        public
        view
        returns (int128)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.curveCoinIds[_supportPid];
    }

    function getUserLendingState(bytes32 _lendingId)
        public
        view
        returns (UserLendingState)
    {
        LendingInfo memory lendingInfo = lendings[_lendingId];

        return lendingInfo.state;
    }

    /* function getLiquidateInfo(bytes32 _lendingId)
        public
        view
        returns (bool, uint256)
    {
        LendingInfo memory lendingInfo = lendings[_lendingId];
        UserLending memory userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        uint256 liquidateBlockNumbers = lendingInfo
            .startedBlock
            .add(userLending.borrowNumbers)
            .sub(liquidateThresholdBlockNumbers);

        if (liquidateBlockNumbers < block.number)
            return (true, liquidateBlockNumbers);

        return (false, liquidateBlockNumbers);
    } */

    function getLendingInfo(
        uint256 _token0,
        uint256 _convexPid,
        int128 _curveCoinId,
        uint256 _compoundPid,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold,
        uint256 _borrowBlocks
    ) public view returns (LendingParams memory) {
        (address lpToken, uint256 token0Price) = _getCurveInfo(
            _convexPid,
            _curveCoinId,
            _token0
        );

        uint256 collateralFactorMantissa = ICompoundBooster(compoundBooster)
            .getCollateralFactorMantissa(_compoundPid);
        uint256 utilizationRate = ICompoundBooster(compoundBooster)
            .getUtilizationRate(_compoundPid);
        uint256 compoundRatePerBlock = ICompoundBooster(compoundBooster)
            .getBorrowRatePerBlock(_compoundPid);
        uint256 compoundRate = getCompoundRate(
            compoundRatePerBlock,
            _borrowBlocks
        );
        uint256 amplificationFactor = getAmplificationFactor(utilizationRate);
        uint256 lendFlareRate;

        if (utilizationRate > 0) {
            lendFlareRate = getLendFlareRate(compoundRate, amplificationFactor);
        } else {
            lendFlareRate = compoundRate.sub(1e18);
        }

        uint256 lendingAmount = (token0Price *
            1e18 *
            (1000 - _lendingThreshold - _liquidateThreshold)) /
            (1e18 + lendFlareRate) /
            1000;

        uint256 collateralAmount = lendingAmount
            .mul(compoundRate)
            .mul(1000)
            .div(800)
            .div(collateralFactorMantissa);

        uint256 interestAmount = lendingAmount.mul(lendFlareRate).div(1e18);

        return
            LendingParams({
                lendingAmount: lendingAmount,
                collateralAmount: collateralAmount,
                interestAmount: interestAmount,
                borrowRate: lendFlareRate,
                utilizationRate: utilizationRate,
                compoundRatePerBlock: compoundRatePerBlock,
                lpToken: lpToken,
                token0Price: token0Price
            });
    }

    function getUserLendingsLength(address _user)
        public
        view
        returns (uint256)
    {
        return userLendings[_user].length;
    }

    function getCompoundRate(uint256 _compoundBlockRate, uint256 n)
        public
        pure
        returns (uint256)
    {
        _compoundBlockRate = _compoundBlockRate + (10**18);

        for (uint256 i = 1; i <= n; i++) {
            _compoundBlockRate = (_compoundBlockRate**2) / (10**18);
        }

        return _compoundBlockRate;
    }

    function getAmplificationFactor(uint256 _utilizationRate)
        public
        pure
        returns (uint256)
    {
        if (_utilizationRate <= 0.9 * 1e18) {
            return uint256(10).mul(_utilizationRate).div(9).add(1e18);
        }

        return uint256(20).mul(_utilizationRate).sub(16 * 1e18);
    }

    function getLendFlareRate(
        uint256 _compoundRate,
        uint256 _amplificationFactor
    ) public pure returns (uint256) {
        return _compoundRate.sub(1e18).mul(_amplificationFactor).div(1e18);
    }

    function getEncodePacked(
        uint256 _pid,
        uint256 _supportPid,
        address _sender
    ) public pure returns (bytes32) {
        if (_sender == address(0)) {
            return generateId(_sender, _pid, _supportPid);
        }

        return generateId(_sender, _pid, _supportPid);
    }
}