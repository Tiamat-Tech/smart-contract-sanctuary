// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vesting.sol";

contract VestingFactory is Ownable {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private vestings;

    event AddVesting(address indexed sender, address vesting, bool isPrivate);
    event RemoveVesting(address indexed sender, address vesting);

    function isRegistered(address _vesting) external view returns (bool) {
        return vestings.contains(_vesting);
    }

    function list(uint256 _offset, uint256 _limit)
        external
        view
        returns (address[] memory result)
    {
        uint256 to = (_offset + _limit).min(vestings.length()).max(_offset);

        result = new address[](to - _offset);

        for (uint256 i = _offset; i < to; i++) {
            result[i - _offset] = vestings.at(i);
        }
    }

    function add(address _vesting, bool _isPrivate) external onlyOwner {
        _add(_vesting, _isPrivate);
    }

    function remove(address _vesting) external onlyOwner {
        bool success = vestings.remove(_vesting);
        require(success, "Register: Not found");

        emit RemoveVesting(msg.sender, _vesting);
    }

    function createVesting(
        string memory name_,
        address rewardToken_,
        address depositToken_,
        address signer_,
        uint256 initialUnlockPercentage_,
        uint256 minAllocation_,
        uint256 maxAllocation_,
        Vesting.VestingType vestingType_
    ) external onlyOwner {
        Vesting vest = new Vesting(
            name_,
            rewardToken_,
            depositToken_,
            signer_,
            initialUnlockPercentage_,
            minAllocation_,
            maxAllocation_,
            vestingType_
        );

        vest.transferOwnership(owner());

        _add(address(vest), false);
    }

    function _add(address _vesting, bool _isPrivate) internal {
        bool success = vestings.add(_vesting);
        require(success, "Register: Already exists");

        emit AddVesting(_msgSender(), _vesting, _isPrivate);
    }
}