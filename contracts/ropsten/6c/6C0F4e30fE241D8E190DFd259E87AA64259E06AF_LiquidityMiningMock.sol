pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LiquidityMiningMock {
    using SafeMath for uint256;

    IERC20 public rewardToken;
    IERC20 public stakedToken;

    uint256 public startBlock;
    uint256 public rewardPerBlock;

    mapping(address => uint256) public balances;

    constructor(
        address _stakedToken,
        address _rewardToken,
        uint256 _startBlock,
        uint256 _rewardPerBlock
    ) {
        rewardToken = IERC20(_rewardToken);
        stakedToken = IERC20(_stakedToken);
        startBlock = _startBlock;
        rewardPerBlock = _rewardPerBlock;
    }

    function getAPY() external view returns (uint256) {
        return 100;
    }

    function getWeeklyRewards(address recipient)
        external
        view
        returns (uint256)
    {
        return 25;
    }

    function getPoolShare(address recipient)
        external
        view
        returns (uint256 percentage, uint256 currency)
    {
        return (50, 5);
    }

    function getAvailHarvest(address recipient) public view returns (uint256) {
        return 25;
    }

    function getTotalLiquidity() external view returns (uint256) {
        return 167778;
    }

    function stake(uint256 amount) external {
        stakedToken.transferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        balances[msg.sender] = balances[msg.sender].sub(amount);
    }

    function harvest() external {
        _harvest(msg.sender);
    }

    function harvestFor(address recipient) external {
        _harvest(recipient);
    }

    function _harvest(address recipient) internal {
        uint256 harv = getAvailHarvest(recipient);
        require(harv > 0, "Not enofugh harvest");
        rewardToken.transfer(recipient, harv);
    }
}