// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libs/SafeERC20.sol";
import "./libs/Clones.sol";
import "./compound/CompoundInterfaces.sol";
import "./common/IVirtualBalanceWrapper.sol";

contract CompoundBooster {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public compoundComptroller;
    address public compoundProxyUserTemplate;
    address public virtualBalanceWrapperFactory;
    address public compoundPoolFactory;
    address public rewardCompToken;
    address public lendFlareVotingEscrow;

    address public Lending;

    struct PoolInfo {
        address lpToken;
        address rewardCompPool; // comp 收益
        address rewardVeLendFlarePool; // veLFT 利息50%
        address rewardInterestPool; // 利息50% ctoken持有者
        address treasuryFund;
        address virtualBalance; // 质押的ctoken
        address lendflareGauge;
        bool isErc20;
        bool shutdown;
    }

    enum LendingInfoState {
        NONE,
        LOCK,
        UNLOCK,
        LIQUIDATE
    }

    struct LendingInfo {
        uint256 pid;
        address payable proxyUser;
        uint256 cTokens;
        address underlyToken;
        uint256 amount;
        uint256 borrowNumbers; // 借款周期 区块长度
        uint256 startedBlock; // 创建借贷的区块
        LendingInfoState state;
    }

    PoolInfo[] public poolInfo;

    mapping(uint256 => uint256) public frozenCTokens;
    mapping(bytes32 => LendingInfo) public lendingInfos;

    event Minted(address indexed user, uint256 indexed pid, uint256 amount);
    event Deposited(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed pid, uint256 amount);
    event RepayBorrow(
        bytes32 indexed lendingId,
        address indexed user,
        uint256 amount,
        uint256 interestValue,
        bool isErc20
    );
    event Liquidate(
        bytes32 indexed lendingId,
        uint256 lendingAmount,
        uint256 interestValue
    );

    modifier onlyLending() {
        _;
    }

    function init(
        address _virtualBalanceWrapperFactory,
        address _compoundPoolFactory,
        address _rewardCompToken,
        address _lendFlareVotingEscrow,
        address _compoundProxyUserTemplate
    ) public {
        virtualBalanceWrapperFactory = _virtualBalanceWrapperFactory;
        compoundPoolFactory = _compoundPoolFactory;
        rewardCompToken = _rewardCompToken;
        lendFlareVotingEscrow = _lendFlareVotingEscrow;

        compoundProxyUserTemplate = _compoundProxyUserTemplate;
    }

    function addPool(address _lpToken, bool _isErc20) public returns (bool) {
        address virtualBalance = IVirtualBalanceWrapperFactory(
            virtualBalanceWrapperFactory
        ).CreateVirtualBalanceWrapper(address(this));

        address rewardCompPool = ICompoundPoolFactory(compoundPoolFactory)
            .CreateCompoundRewardPool(
                rewardCompToken,
                address(virtualBalance),
                address(this)
            );

        address rewardVeLendFlarePool;
        address interestRewardPool;

        if (_isErc20) {
            address underlyToken = ICompoundCErc20(_lpToken).underlying();
            interestRewardPool = ICompoundPoolFactory(compoundPoolFactory)
                .CreateCompoundInterestRewardPool(
                    underlyToken,
                    virtualBalance,
                    address(this)
                );
            rewardVeLendFlarePool = ICompoundPoolFactory(compoundPoolFactory)
                .CreateCompoundInterestRewardPool(
                    underlyToken,
                    lendFlareVotingEscrow,
                    address(this)
                );
        } else {
            interestRewardPool = ICompoundPoolFactory(compoundPoolFactory)
                .CreateCompoundInterestRewardPool(
                    address(0),
                    virtualBalance,
                    address(this)
                );
            rewardVeLendFlarePool = ICompoundPoolFactory(compoundPoolFactory)
                .CreateCompoundInterestRewardPool(
                    address(0),
                    lendFlareVotingEscrow,
                    address(this)
                );
        }

        address treasuryFundPool = ICompoundPoolFactory(compoundPoolFactory)
            .CreateTreasuryFundPool(address(this));

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                rewardCompPool: rewardCompPool,
                rewardVeLendFlarePool: rewardVeLendFlarePool,
                rewardInterestPool: interestRewardPool,
                treasuryFund: treasuryFundPool,
                virtualBalance: virtualBalance,
                lendflareGauge: address(0),
                isErc20: _isErc20,
                shutdown: false
            })
        );

        return true;
    }

    function _mintEther(address lpToken, uint256 _amount) internal {
        ICompoundCEther(lpToken).mint{value: _amount}();
    }

    function _mintErc20(address lpToken, uint256 _amount) internal {
        ICompoundCErc20(lpToken).mint(_amount);
    }

    /**
        @param _amount 质押金额,将转入treasuryFunds
        @param _isCToken 是否参与转化为cToken,如果开启，_amount 将为 erc20的转化金额
     */
    function deposit(
        uint256 _pid,
        uint256 _amount,
        bool _isCToken
    ) public payable returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        if (!_isCToken) {
            if (pool.isErc20) {
                require(_amount > 0);

                address underlyToken = ICompoundCErc20(pool.lpToken)
                    .underlying();

                IERC20(underlyToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    _amount
                );

                IERC20(underlyToken).safeApprove(pool.lpToken, 0);
                IERC20(underlyToken).safeApprove(pool.lpToken, _amount);

                _mintErc20(pool.lpToken, _amount);
            } else {
                require(msg.value > 0 && _amount == 0);

                _mintEther(pool.lpToken, msg.value);
            }
        } else {
            IERC20(pool.lpToken).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        uint256 mintToken = IERC20(pool.lpToken).balanceOf(address(this));

        require(mintToken > 0, "mintToken = 0");

        IERC20(pool.lpToken).safeTransfer(pool.treasuryFund, mintToken);
        IVirtualBalanceWrapper(pool.virtualBalance).stakeFor(
            msg.sender,
            mintToken
        );

        if (pool.lendflareGauge != address(0)) {
            ILendFlareGague(pool.lendflareGauge).user_checkpoint(msg.sender);
        }

        emit Deposited(msg.sender, _pid, mintToken);

        return true;
    }

    function withdraw(uint256 _pid, uint256 _amount) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        uint256 depositAmount = IRewardPool(pool.rewardCompPool).balanceOf(
            msg.sender
        );

        require(
            IERC20(pool.lpToken).balanceOf(pool.treasuryFund) >= _amount,
            "!Insufficient balance"
        );
        require(_amount <= depositAmount, "!depositAmount");

        ICompoundTreasuryFund(pool.treasuryFund).withdrawTo(
            pool.lpToken,
            _amount,
            msg.sender
        );

        IVirtualBalanceWrapper(pool.virtualBalance).withdrawFor(
            msg.sender,
            _amount
        );

        return true;
    }

    function claimComp() external returns (bool) {
        address compAddress = ICompoundComptroller(compoundComptroller)
            .getCompAddress();
        uint256 balanceOfComp;

        for (uint256 i = 0; i < this.poolLength(); i++) {
            if (poolInfo[i].shutdown) {
                continue;
            }

            balanceOfComp = balanceOfComp.add(
                ICompoundTreasuryFund(poolInfo[i].treasuryFund).claimComp(
                    compAddress,
                    compoundComptroller,
                    poolInfo[i].rewardCompPool
                )
            );
        }

        return true;
    }

    function setCompoundComptroller(address _v) public {
        compoundComptroller = _v;
    }

    function setLendFlareGauge(uint256 _pid, address _v) public {
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.lendflareGauge == address(0), "!lendflareGauge");

        pool.lendflareGauge = _v;
    }

    receive() external payable {}

    function getRewards(uint256 _pid) public {
        PoolInfo memory pool = poolInfo[_pid];

        if (IRewardPool(pool.rewardCompPool).earned(msg.sender) > 0) {
            IRewardPool(pool.rewardCompPool).getReward(msg.sender);
        }

        if (IRewardPool(pool.rewardInterestPool).earned(msg.sender) > 0) {
            IRewardPool(pool.rewardInterestPool).getReward(msg.sender);
        }

        if (IRewardPool(pool.rewardVeLendFlarePool).earned(msg.sender) > 0) {
            IRewardPool(pool.rewardVeLendFlarePool).getReward(msg.sender);
        }
    }

    function getAllRewards() public {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            getRewards(pid);
        }
    }

    /* lending interfaces */
    function cloneUserTemplate(
        uint256 _pid,
        bytes32 _lendingId,
        address _treasuryFund,
        address _sender
    ) internal {
        LendingInfo memory lendingInfo = lendingInfos[_lendingId];

        if (lendingInfo.startedBlock == 0) {
            address payable template = payable(
                Clones.clone(compoundProxyUserTemplate)
            );

            ICompoundProxyUserTemplate(template).init(
                address(this),
                _treasuryFund,
                _lendingId,
                _sender,
                rewardCompToken
            );

            lendingInfos[_lendingId] = LendingInfo({
                pid: _pid,
                proxyUser: template,
                cTokens: 0,
                underlyToken: address(0),
                amount: 0,
                startedBlock: 0,
                borrowNumbers: 0,
                state: LendingInfoState.NONE
            });
        }
    }

    function borrow(
        uint256 _pid,
        bytes32 _lendingId,
        address _user,
        uint256 _lendingAmount,
        uint256 _collateralAmount,
        uint256 _borrowNumbers
    ) public {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 exchangeRateStored = ICompound(pool.lpToken)
            .exchangeRateStored();
        uint256 cTokens = _collateralAmount.mul(1e18).div(exchangeRateStored);

        require(
            IERC20(pool.lpToken).balanceOf(pool.treasuryFund) >= cTokens,
            "!Insufficient balance"
        );

        frozenCTokens[_pid] = frozenCTokens[_pid].add(cTokens);

        cloneUserTemplate(_pid, _lendingId, pool.treasuryFund, _user);

        LendingInfo storage lendingInfo = lendingInfos[_lendingId];

        lendingInfo.cTokens = cTokens;
        lendingInfo.amount = _lendingAmount;
        lendingInfo.startedBlock = block.number;
        lendingInfo.borrowNumbers = _borrowNumbers;
        lendingInfo.state = LendingInfoState.LOCK;

        ICompoundTreasuryFund(pool.treasuryFund).withdrawTo(
            pool.lpToken,
            cTokens,
            lendingInfo.proxyUser
        );

        if (pool.isErc20) {
            address underlyToken = ICompoundCErc20(pool.lpToken).underlying();

            lendingInfo.underlyToken = underlyToken;

            ICompoundProxyUserTemplate(lendingInfo.proxyUser).borrowErc20(
                pool.lpToken,
                underlyToken,
                _user,
                _lendingAmount
            );
        } else {
            lendingInfo.underlyToken = address(0);

            ICompoundProxyUserTemplate(lendingInfo.proxyUser).borrow(
                pool.lpToken,
                payable(_user),
                _lendingAmount
            );
        }
    }

    function _repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _amount,
        uint256 _interestValue,
        bool _isErc20
    ) internal {
        LendingInfo storage lendingInfo = lendingInfos[_lendingId];
        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        require(lendingInfo.state == LendingInfoState.LOCK, "!LOCK");

        frozenCTokens[lendingInfo.pid] = frozenCTokens[lendingInfo.pid].sub(
            lendingInfo.cTokens
        );

        if (_isErc20) {
            uint256 bal = ICompoundProxyUserTemplate(lendingInfo.proxyUser)
                .repayBorrowErc20(
                    pool.lpToken,
                    lendingInfo.underlyToken,
                    _user,
                    _amount
                );

            if (bal > 0) {
                uint256 exchangeReward = bal.mul(50).div(100);
                uint256 lendflareDeposterReward = bal.mul(50).div(100);

                IERC20(lendingInfo.underlyToken).safeTransfer(
                    pool.rewardInterestPool,
                    exchangeReward
                );
                IERC20(lendingInfo.underlyToken).safeTransfer(
                    pool.rewardVeLendFlarePool,
                    lendflareDeposterReward
                );

                ICompoundInterestRewardPool(pool.rewardInterestPool)
                    .queueNewRewards(exchangeReward);

                ICompoundInterestRewardPool(pool.rewardVeLendFlarePool)
                    .queueNewRewards(lendflareDeposterReward);
            }
        } else {
            uint256 bal = ICompoundProxyUserTemplate(lendingInfo.proxyUser)
                .repayBorrow{value: _amount}(pool.lpToken, payable(_user));

            if (bal > 0) {
                uint256 exchangeReward = bal.mul(50).div(100);
                uint256 lendflareDeposterReward = bal.mul(50).div(100);

                payable(pool.rewardInterestPool).transfer(exchangeReward);
                payable(pool.rewardVeLendFlarePool).transfer(
                    lendflareDeposterReward
                );
                ICompoundInterestRewardPool(pool.rewardInterestPool)
                    .queueNewRewards(exchangeReward);

                ICompoundInterestRewardPool(pool.rewardVeLendFlarePool)
                    .queueNewRewards(lendflareDeposterReward);
                // lendflareDeposterReward

                // IERC20(pool.rewardInterestPool).transfer(
                //     address(this),
                //     exchangeReward
                // );
                // IERC20(lendflareDepositer).transfer(
                //     address(this),
                //     lendflareDeposterReward
                // );
            }
        }

        ICompoundProxyUserTemplate(lendingInfo.proxyUser).recycle(
            pool.lpToken,
            lendingInfo.underlyToken
        );

        lendingInfo.state = LendingInfoState.UNLOCK;

        emit RepayBorrow(_lendingId, _user, _amount, _interestValue, _isErc20);
    }

    function repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _interestValue
    ) external payable {
        _repayBorrow(_lendingId, _user, msg.value, _interestValue, false);
    }

    // lending合约授权，并扣款，转入当前合约，此合约再将钱转入代理人
    function repayBorrowErc20(
        bytes32 _lendingId,
        address _user,
        uint256 _amount, // 不包含利息
        uint256 _interestValue
    ) external {
        _repayBorrow(_lendingId, _user, _amount, _interestValue, true);
    }

    function liquidate(
        bytes32 _lendingId,
        uint256 _lendingAmount,
        uint256 _interestValue
    ) public payable returns (address) {
        LendingInfo storage lendingInfo = lendingInfos[_lendingId];
        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        require(lendingInfo.state == LendingInfoState.LOCK, "!LOCK");

        frozenCTokens[lendingInfo.pid] = frozenCTokens[lendingInfo.pid].sub(
            lendingInfo.cTokens
        );

        // 拍卖的钱由lending专递给myProxyUser,所以直接从主账户里转ctoken去还款
        uint256 bal = ICompoundProxyUserTemplate(lendingInfo.proxyUser)
            .repayBorrowBySelf{value: msg.value}(
            pool.lpToken,
            /* veLendFlareReward, */
            lendingInfo.underlyToken
        );

        if (bal > 0) {
            uint256 exchangeReward = _interestValue.mul(50).div(100);
            uint256 lendflareDeposterReward = _interestValue.mul(50).div(100);

            if (pool.isErc20) {
                IERC20(lendingInfo.underlyToken).safeTransfer(
                    pool.rewardInterestPool,
                    exchangeReward
                );
                IERC20(lendingInfo.underlyToken).safeTransfer(
                    pool.rewardVeLendFlarePool,
                    lendflareDeposterReward
                );

                if (bal > _interestValue) {
                    IERC20(lendingInfo.underlyToken).safeTransfer(
                        pool.rewardVeLendFlarePool,
                        bal.sub(_interestValue)
                    );
                }
            } else {
                payable(pool.rewardInterestPool).transfer(exchangeReward);
                payable(pool.rewardVeLendFlarePool).transfer(
                    lendflareDeposterReward
                );

                if (bal > _interestValue) {
                    payable(pool.rewardVeLendFlarePool).transfer(
                        bal.sub(_interestValue)
                    );
                }
            }

            ICompoundInterestRewardPool(pool.rewardInterestPool)
                .queueNewRewards(exchangeReward);
            ICompoundInterestRewardPool(pool.rewardVeLendFlarePool)
                .queueNewRewards(lendflareDeposterReward);
        }

        lendingInfo.state = LendingInfoState.UNLOCK;

        emit Liquidate(_lendingId, _lendingAmount, _interestValue);

        // // 拍卖的钱由lending专递给myProxyUser,所以直接从主账户里转ctoken去还款
    }

    /* view functions */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function totalSupplyOf(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        return IERC20(pool.lpToken).balanceOf(address(this));
    }

    function getUtilizationRate(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 currentBal = IERC20(pool.lpToken).balanceOf(pool.treasuryFund);

        if (currentBal == 0 || frozenCTokens[_pid] == 0) {
            return 0;
        }

        // return currentBal.mul(1e18).div(currentBal.add(frozenCTokens[_pid]));
        return
            frozenCTokens[_pid].mul(1e18).div(
                currentBal.add(frozenCTokens[_pid])
            );
    }

    function getBorrowRatePerBlock(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        return ICompound(pool.lpToken).borrowRatePerBlock();
    }

    function getExchangeRateStored(uint256 _pid)
        external
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return ICompound(pool.lpToken).exchangeRateStored();
    }

    function getCollateralFactorMantissa(uint256 _pid)
        public
        view
        returns (uint256)
    {
        PoolInfo memory pool = poolInfo[_pid];

        ICompoundComptroller comptroller = ICompound(pool.lpToken)
            .comptroller();
        (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(
            pool.lpToken
        );

        return isListed ? collateralFactorMantissa : 800000000000000000;
    }

    function getLendingInfos(bytes32 _lendingId)
        public
        view
        returns (address payable, address)
    {
        LendingInfo memory lendingInfo = lendingInfos[_lendingId];

        return (lendingInfo.proxyUser, lendingInfo.underlyToken);
    }

    // function getBlocksPerYears(uint256 _pid, bool isSplit)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     // WhitePaperInterestRateModel
    //     //uint public constant blocksPerYear = 2102400;
    //     PoolInfo memory pool = poolInfo[_pid];

    //     uint256 blocks = ICompoundInterestRateModel(
    //         ICompound(pool.lpToken).interestRateModel()
    //     ).blocksPerYear();

    //     if (isSplit) {
    //         return blocks.div(365 days);
    //     }

    //     return blocks;
    // }
}