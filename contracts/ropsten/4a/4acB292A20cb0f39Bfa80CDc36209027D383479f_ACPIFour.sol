//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RealT.sol";
import "./IACPI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ACPIFour is IACPI, Ownable {
    mapping(address => uint256) private _balance;
    uint256 private _acpiPrice;
    RealT private realtERC20;

    constructor(address owner) {
        transferOwnership(owner);
        _acpiPrice = 0;
        realtERC20 = RealT(msg.sender);
    }

    /**
     * @dev Returns the amount of rounds per ACPI.
     */
    function totalRound() external override pure returns (uint256) {
        return 18;
    }

    /**
     * @dev Returns the amount of blocks per ACPI.
     */
    function roundTime() external override view returns (uint256) {}

    /**
     * @dev Start round of ACPI ending the last one.
     */
    function startRound() public override onlyOwner {}


    /**
     * @dev Returns the average value for target ACPI will be 0 until acpi end
     */
    function acpiPrice() external override view returns (uint256) {
        return _acpiPrice;
    }
}