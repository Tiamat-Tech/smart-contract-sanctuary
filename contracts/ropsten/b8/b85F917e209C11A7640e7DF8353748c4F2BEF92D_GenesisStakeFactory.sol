pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../management/Managed.sol";
import "../management/Constants.sol";
import "../interfaces/factorys/IGenesisStakeFactory.sol";
import "../interfaces/stakings/IGenesisStaking.sol";
import "../stakings/GenesisStaking.sol";

contract GenesisStakeFactory is IGenesisStakeFactory, Managed {
    using SafeMath for uint256;
    using Math for uint256;

    uint256 public blockPerDay = 6450;

    mapping(address => uint256) public stakingIndex;
    mapping(address => address[]) public ownerStakes;
    mapping(address => mapping(address => uint256)) ownerIndex;

    address[] public staking;

    modifier canCreate() {
        require(
            hasPermission(_msgSender(), ROLE_ADMIN) ||
                hasPermission(_msgSender(), ROLE_REGULAR),
            "You don't have permission's"
        );
        _;
    }

    modifier canChange(address stakingAddr) {
        require(
            hasPermission(_msgSender(), ROLE_ADMIN) ||
                (hasPermission(_msgSender(), ROLE_REGULAR) &&
                    ownerIndex[msg.sender][stakingAddr] != 0),
            "You don't have permission's"
        );
        _;
    }

    constructor(address _management) Managed(_management) {}

    function list(uint256 _offset, uint256 _limit)
        external
        view
        override
        returns (address[] memory result)
    {
        uint256 to = (_offset.add(_limit)).min(staking.length).max(_offset);

        result = new address[](to - _offset);

        for (uint256 i = _offset; i < to; i++) {
            result[i - _offset] = staking[i];
        }
    }

    function getBlockPerDay() external view override returns (uint256) {
        return blockPerDay;
    }

    function listByUser(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view override returns (address[] memory result) {
        uint256 to =
            (_offset.add(_limit)).min(ownerStakes[_user].length).max(_offset);

        result = new address[](to - _offset);

        for (uint256 i = _offset; i < to; i++) {
            result[i - _offset] = ownerStakes[_user][i];
        }
    }

    function createGenesisStaking(
        string memory _stakingName,
        bool _isETHStake,
        bool _isPrivate,
        address _stakedToken,
        uint256 _startBlock,
        uint256 _duration
    ) external override canCreate {
        GenesisStaking stake =
            new GenesisStaking(
                address(management),
                _stakingName,
                _isETHStake,
                _isPrivate,
                false,
                _stakedToken,
                _startBlock,
                _duration,
                PERCENTAGE_1
            );

        address stakeAddress = address(stake);
        ownerStakes[msg.sender].push(stakeAddress);
        ownerIndex[msg.sender][stakeAddress] = ownerStakes[msg.sender].length;
        staking.push(stakeAddress);
        stakingIndex[stakeAddress] = staking.length;

        emit CreateStaking(_msgSender(), address(stake));
    }

    function add(address _owner, address _addr)
        external
        override
        requirePermission(ROLE_ADMIN)
    {
        require(
            ownerIndex[_owner][_addr] == 0,
            "GF: Owner already has this staking"
        );

        staking.push(_addr);
        stakingIndex[_addr] = staking.length;

        ownerStakes[_owner].push(_addr);
        ownerIndex[_owner][_addr] = ownerStakes[_owner].length;
    }

    function remove(address _owner, address _addr)
        external
        override
        requirePermission(ROLE_ADMIN)
    {
        delete staking[stakingIndex[_addr]];
        delete stakingIndex[_addr];
        delete ownerStakes[_owner][ownerIndex[_owner][_addr]];
        delete ownerIndex[_owner][_addr];
    }

    function setDepositeFee(address _addr, uint256 _amount)
        external
        override
        requirePermission(ROLE_ADMIN)
    {
        IGenesisStaking(_addr).setDepositeFee(_amount);
        emit DepositFeeChange(_msgSender(), _addr, _amount);
    }

    function setBlockPerDay(uint256 _amount)
        external
        override
        requirePermission(ROLE_ADMIN)
    {
        blockPerDay = _amount;
        emit BlockPerDayChange(_msgSender(), _amount);
    }

    function setCanTakeReward(address _addr, bool _value)
        external
        override
        canChange(_addr)
    {
        IGenesisStaking(_addr).setCanTakeReward(_value);
        emit SetCanTakeRewardChange(_msgSender(), _addr, _value);
    }

    function setPrivate(address _addr, bool _value)
        external
        override
        canChange(_addr)
    {
        IGenesisStaking(_addr).setPrivate(_value);
        emit PrivateSet(_msgSender(),_addr, _value);
    }

    function setSettingReward(
        address _addr,
        address[] memory _rewardTokens,
        uint256[] memory _rewardPerBlock
    ) external canChange(_addr) {
        require(
            (_rewardTokens.length == _rewardPerBlock.length),
            "GF: Reward settings are incorrect"
        );

        IGenesisStaking genesisStaking = IGenesisStaking(_addr);
        uint256 startBlock;
        uint256 rewardEndBlock;
        uint256 rewardMustBePaid;
        (startBlock, rewardEndBlock) = genesisStaking.getTimePoint();
        startBlock = Math.max(block.number, startBlock);

        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardMustBePaid = genesisStaking.getMustBePaid(_rewardTokens[i]);
            _calculateAndTransfer(
                _rewardTokens[i],
                address(genesisStaking),
                rewardEndBlock,
                startBlock,
                _rewardPerBlock[i],
                rewardMustBePaid
            );
        }

        genesisStaking.setRewardSetting(_rewardTokens, _rewardPerBlock);
    }

    function takeNotUseTokens(address _addr, address _token)
        external
        override
        canChange(_addr)
    {
        IGenesisStaking(_addr).takeNotUseTokens(_token, msg.sender);
        emit TakeTokenFromStaking(msg.sender, _addr, _token);
    }

    function _calculateAndTransfer(
        address token,
        address stakingAddr,
        uint256 rewardEndBlock,
        uint256 startBlock,
        uint256 rewardPerBlock,
        uint256 rewardMustBePaid
    ) internal {
        uint256 needTokens = rewardEndBlock.sub(startBlock).mul(rewardPerBlock);

        uint256 balance =
            IERC20(token).balanceOf(stakingAddr).sub(rewardMustBePaid);
        uint256 amount = needTokens.sub(balance);
        if (needTokens < balance) {
            amount = balance.sub(needTokens);
        }
        IERC20(token).transferFrom(stakingAddr, msg.sender, amount);
    }
}