// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "./interfaces/IDekaToken.sol";
import "./interfaces/IDekaReceiver.sol";
import "./interfaces/IDekaProtocol.sol";

import "./libraries/SafeMath.sol";
import "./libraries/Address.sol";

contract DekaProtocol is IDekaProtocol {
    using SafeMath for uint256;
    using Address for address;

    struct Stake {
        uint256 amountIn;
        uint256 expiry;
        uint256 expireAfter;
        uint256 mintedAmount;
        address staker;
        address receiver;
    }

    uint256 public constant override TIMELOCK = 3 days;
    address public constant override DEKA_TOKEN = 0x992d63281EbF61061fd79623F294d0F0296BeF81; // CONFIG: Current Address (deka.finance.token)

    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant MAX_FPY_FOR_1_YEAR = 5e17;
    uint256 internal constant SECONDS_IN_1_YEAR = 365 * 86400;

    uint256 public override matchRatio;
    address public override matchReceiver;

    mapping(bytes32 => Stake) public override stakes;
    mapping(LockedFunctions => uint256) public override timelock;
    mapping(address => uint256) public override balances;

    event Staked(
        bytes32 _id,
        uint256 _amountIn,
        uint256 _expiry,
        uint256 _expireAfter,
        uint256 _mintedAmount,
        address indexed _staker,
        address indexed _receiver
    );

    event Unstaked(bytes32 _id, uint256 _amountIn, address indexed _staker);

    modifier onlyMatchReceiver {
        require(msg.sender == matchReceiver, "DekaProtocol:: NOT_MATCH_RECEIVER");
        _;
    }

    modifier notLocked(LockedFunctions _lockedFunction) {
        require(
            timelock[_lockedFunction] != 0 && timelock[_lockedFunction] <= block.timestamp,
            "DekaProtocol:: FUNCTION_TIMELOCKED"
        );
        _;
    }

    constructor(address _initialMatchReceiver, uint256 _initialMatchRatio) {
        _setMatchRatio(_initialMatchRatio);
        _setMatchReceiver(_initialMatchReceiver);
    }

    function lockFunction(LockedFunctions _lockedFunction) external override onlyMatchReceiver {
        timelock[_lockedFunction] = type(uint256).max;
    }

    function unlockFunction(LockedFunctions _lockedFunction) external override onlyMatchReceiver {
        timelock[_lockedFunction] = block.timestamp + TIMELOCK;
    }

    function setMatchReceiver(address _newMatchReceiver)
        external
        override
        onlyMatchReceiver
        notLocked(LockedFunctions.SET_MATCH_RECEIVER)
    {
        _setMatchReceiver(_newMatchReceiver);
        timelock[LockedFunctions.SET_MATCH_RECEIVER] = 0;
    }

    function _setMatchReceiver(address _newMatchReceiver) internal {
        matchReceiver = _newMatchReceiver;
    }

    function setMatchRatio(uint256 _newMatchRatio)
        external
        override
        onlyMatchReceiver
        notLocked(LockedFunctions.SET_MATCH_RATIO)
    {
        _setMatchRatio(_newMatchRatio);
        timelock[LockedFunctions.SET_MATCH_RATIO] = 0;
    }

    function _setMatchRatio(uint256 _newMatchRatio) internal {
        require(_newMatchRatio >= 0 && _newMatchRatio <= 2000, "DekaProtocol:: INVALID_MATCH_RATIO");
        // can be 0 and cannot be above 20%
        require(_newMatchRatio <= 2000, "DekaProtocol:: INVALID_MATCH_RATIO");
        matchRatio = _newMatchRatio;
    }

    function stake(
        uint256 _amountIn,
        uint256 _expiry,
        address _receiver,
        bytes calldata _data
    )
        external
        override
        returns (
            uint256,
            uint256,
            bytes32
        )
    {
        return _stake(_amountIn, _expiry, _receiver, _data);
    }

    function stakeWithPermit(
        address _receiver,
        uint256 _amountIn,
        uint256 _expiry,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        bytes calldata _data
    )
        external
        override
        returns (
            uint256,
            uint256,
            bytes32
        )
    {
        IDekaToken(DEKA_TOKEN).permit(msg.sender, address(this), type(uint256).max, _deadline, _v, _r, _s);
        return _stake(_amountIn, _expiry, _receiver, _data);
    }

    function _stake(
        uint256 _amountIn,
        uint256 _expiry,
        address _receiver,
        bytes calldata _data
    )
        internal
        returns (
            uint256 mintedAmount,
            uint256 matchedAmount,
            bytes32 id
        )
    {
        require(_amountIn > 0, "DekaProtocol:: INVALID_AMOUNT");
        require(_receiver != address(this), "DekaProtocol:: INVALID_ADDRESS");
        require(_expiry <= calculateMaxStakePeriod(_amountIn), "DekaProtocol:: MAX_STAKE_PERIOD_EXCEEDS");

        address staker = msg.sender;

        uint256 expiration = block.timestamp.add(_expiry);
        balances[staker] = balances[staker].add(_amountIn);

        id = keccak256(abi.encodePacked(_amountIn, _expiry, _receiver, staker, block.timestamp));

        require(stakes[id].staker == address(0), "DekaProtocol:: STAKE_EXISTS");

        mintedAmount = getMintAmount(_amountIn, _expiry);
        matchedAmount = getMatchedAmount(mintedAmount);

        IDekaToken(DEKA_TOKEN).transferFrom(staker, address(this), _amountIn);

        IDekaToken(DEKA_TOKEN).mint(_receiver, mintedAmount);
        IDekaToken(DEKA_TOKEN).mint(matchReceiver, matchedAmount);

        stakes[id] = Stake(_amountIn, _expiry, expiration, mintedAmount, staker, _receiver);

        if (_receiver.isContract()) {
            IDekaReceiver(_receiver).receiveDeka(id, _amountIn, expiration, mintedAmount, staker, _data);
        }

        emit Staked(id, _amountIn, _expiry, expiration, mintedAmount, staker, _receiver);
    }

    function unstake(bytes32 _id) external override returns (uint256 withdrawAmount) {
        Stake memory s = stakes[_id];
        require(block.timestamp >= s.expireAfter, "DekaProtocol:: STAKE_NOT_EXPIRED");
        balances[s.staker] = balances[s.staker].sub(s.amountIn);
        withdrawAmount = s.amountIn;
        delete stakes[_id];
        IDekaToken(DEKA_TOKEN).transfer(s.staker, withdrawAmount);
        emit Unstaked(_id, s.amountIn, s.staker);
    }

    function unstakeEarly(bytes32 _id) external override returns (uint256 withdrawAmount) {
        Stake memory s = stakes[_id];
        address staker = msg.sender;
        require(s.staker == staker, "DekaProtocol:: INVALID_STAKER");
        uint256 remainingTime = (s.expireAfter.sub(block.timestamp));
        require(s.expiry > remainingTime, "DekaProtocol:: INVALID_UNSTAKE_TIME");
        uint256 burnAmount = _calculateBurn(s.amountIn, remainingTime, s.expiry);
        assert(burnAmount <= s.amountIn);
        balances[staker] = balances[staker].sub(s.amountIn);
        withdrawAmount = s.amountIn.sub(burnAmount);
        delete stakes[_id];
        IDekaToken(DEKA_TOKEN).burn(burnAmount);
        IDekaToken(DEKA_TOKEN).transfer(staker, withdrawAmount);
        emit Unstaked(_id, withdrawAmount, staker);
    }

    function getMatchedAmount(uint256 _mintedAmount) public view override returns (uint256) {
        return _mintedAmount.mul(matchRatio).div(10000);
    }

    function getMintAmount(uint256 _amountIn, uint256 _expiry) public view override returns (uint256) {
        return _amountIn.mul(_expiry).mul(getFPY(_amountIn)).div(PRECISION * SECONDS_IN_1_YEAR);
    }

    function getFPY(uint256 _amountIn) public view override returns (uint256) {
        return (PRECISION.sub(getPercentageStaked(_amountIn))).div(2);
    }

    function getPercentageStaked(uint256 _amountIn) public view override returns (uint256) {
        uint256 locked = IDekaToken(DEKA_TOKEN).balanceOf(address(this)).add(_amountIn);
        return locked.mul(PRECISION).div(IDekaToken(DEKA_TOKEN).totalSupply());
    }

    function calculateMaxStakePeriod(uint256 _amountIn) public view override returns (uint256) {
        return MAX_FPY_FOR_1_YEAR.mul(SECONDS_IN_1_YEAR).div(getFPY(_amountIn));
    }

    function _calculateBurn(
        uint256 _amount,
        uint256 _remainingTime,
        uint256 _totalTime
    ) private pure returns (uint256) {
        return _amount.mul(_remainingTime).div(_totalTime);
    }
}