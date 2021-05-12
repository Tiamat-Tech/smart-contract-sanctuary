pragma solidity 0.8.4;

import "./PoolMock.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract PoolFactoryMock {
    using SafeMath for uint256;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private pools;

    constructor() {}

    function createPool(
        string memory _name,
        PoolMock.PoolType _poolType,
        uint256 _price,
        uint256 _whitelistStartDate,
        uint256 _whitelistEndDate,
        uint256 _saleStartDate,
        uint256 _saleEndDate,
        uint256 _totalRaise,
        address _stakedToken,
        address _rewardToken
    ) external {
        PoolMock pool =
            new PoolMock(
                _name,
                _poolType,
                _price,
                _whitelistStartDate,
                _whitelistEndDate,
                _saleStartDate,
                _saleEndDate,
                _totalRaise,
                _stakedToken,
                _rewardToken
            );
        pools.add(address(pool));
    }

    function count() external view returns (uint256) {
        return pools.length();
    }

    function list(uint256 _offset, uint256 _limit)
        external
        view
        returns (address[] memory _pools)
    {
        uint256 to = (_offset.add(_limit)).min(pools.length()).max(_offset);

        _pools = new address[](to - _offset);

        for (uint256 i = _offset; i < to; i++) {
            _pools[i - _offset] = pools.at(i);
        }
    }
}