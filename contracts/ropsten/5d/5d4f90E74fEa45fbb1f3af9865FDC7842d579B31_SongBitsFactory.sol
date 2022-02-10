// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.9;

import "./SongBitsCollection.sol";

import "./interfaces/IParams.sol";
import "./interfaces/ITreasury.sol";

import "./utils/Ownable.sol";

contract SongBitsFactory is Ownable {
    address[] public collections;
    address public treasuryContracts;

    constructor(address _treasuryContracts) {
        treasuryContracts = _treasuryContracts;

        _transferOwnership(msg.sender);
    }

    event CreateCollection(address indexed collection, uint256 id);

    function createCollection(IParams.CollectionParams memory params) external {
        address newCollection;
        newCollection = address(
            new SongBitsCollection(params, msg.sender, treasuryContracts)
        );

        collections.push(newCollection);
        ITreasury(treasuryContracts).setFee(newCollection, params._fees);
        emit CreateCollection(newCollection, collections.length - 1);
    }

    function getCollections() public view returns (address[] memory) {
        return collections;
    }

    function setTreasuryContracts(address _treasuryContracts) public onlyOwner {
        treasuryContracts = _treasuryContracts;
    }
}