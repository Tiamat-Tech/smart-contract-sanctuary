pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./LiquidityMiningMock.sol";

contract LiquidityMiningFactoryMock {
    using SafeMath for uint256;
    using Math for uint256;

    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private minings;

    constructor() {}

    function createMining(
        address _stakedToken,
        address _rewardToken,
        uint256 _startRewardBlock,
        uint256 _rewardPerBlock
    ) external {
        LiquidityMiningMock mining =
            new LiquidityMiningMock(
                _stakedToken,
                _rewardToken,
                _startRewardBlock,
                _rewardPerBlock
            );
        minings.add(address(mining));
    }

    function count() external view returns (uint256) {
        return minings.length();
    }

    function list(uint256 _offset, uint256 _limit)
        external
        view
        returns (address[] memory _minings)
    {
        uint256 to = (_offset.add(_limit)).min(minings.length()).max(_offset);

        _minings = new address[](to - _offset);

        for (uint256 i = _offset; i < to; i++) {
            _minings[i - _offset] = minings.at(i);
        }
    }

    function harvestAll(address[] memory miningBatch) external {
        for (uint256 index = 0; index < miningBatch.length; index++) {
            LiquidityMiningMock(miningBatch[index]).harvestFor(msg.sender);
        }
    }
}