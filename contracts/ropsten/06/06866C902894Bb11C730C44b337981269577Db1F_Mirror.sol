// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Mirror is Ownable {
    address[] private whiteLists;

    constructor() {}

    function addWhiteLists(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteLists.push(addresses[i]);
        }
    }

    function getWhiteLists() external view returns (address[] memory) {
        return whiteLists;
    }
}