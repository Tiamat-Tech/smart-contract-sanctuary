pragma solidity ^0.8.0;

interface IFactoryInfo {
    event SetCanTakeRewardChange(
        address indexed sender,
        address staking,
        bool amount
    );

    event Approve(address indexed sender, address staking);
    event Remove(address indexed sender, address staking);

    event DepositFeeChange(
        address indexed sender,
        address staking,
        uint256 amount
    );

    event BlockPerDayChange(address indexed sender, uint256 amount);
    event PrivateSet(address indexed sender, address staking, bool value);

    event TakeTokenFromStaking(
        address indexed user,
        address staking,
        address token
    );

    function list(uint256 _offset, uint256 _limit)
        external
        view
        returns (address[] memory result);

    function listByUser(
        address _user,
        uint256 _offset,
        uint256 _limit
    ) external view returns (address[] memory result);

    function getBlockPerDay() external view returns (uint256);

    function add(address _owner, address _addr) external;

    function remove(address _owner, address _addr) external;

    function setDepositeFee(address _addr, uint256 _amount) external;

    function setBlockPerDay(uint256 _amount) external;

    function setCanTakeReward(address _addr, bool _value) external;

    function takeNotUseTokens(address _addr, address _token) external;

    function setPrivate(address _addr, bool _value) external;
}