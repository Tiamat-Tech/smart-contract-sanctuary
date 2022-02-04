// contracts/AdminBox.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AdminBoxV2 is Initializable, UUPSUpgradeable, OwnableUpgradeable{
    mapping (address => uint) public values;

    // Emitted when the stored value changes
    event ValueChanged(address indexed user, uint256 value);

    function initialize() public initializer {
      __Ownable_init();
    }

    // Stores a new value in the contract
    function store(address user, uint256 value) public onlyOwner {
        values[user]=value*2;
        emit ValueChanged(user, value);
    }
    
    function _authorizeUpgrade(address) internal override onlyOwner {}
}