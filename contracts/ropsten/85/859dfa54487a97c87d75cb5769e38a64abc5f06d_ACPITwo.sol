//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./RealT.sol";
import "./IACPI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ACPITwo is IACPI, Ownable {
    mapping(address => uint256) private _balance;
    uint256 private _acpiPrice;
    RealT private realtERC20;

    constructor(address realtAddress) {
        _acpiPrice = 0;
        realtERC20 = RealT(realtAddress);
    }

    /**
     * @dev Returns the amount of rounds per ACPI.
     */
    function totalRound() external override view returns (uint256) {}

    /**
     * @dev Returns the amount of blocks per ACPI.
     */
    function roundTime() external override pure returns (uint256) {}

    /**
     * @dev Returns the amount of tokens invested by `account`.
     */
    function investOf(address account) public override view returns (uint256) {
        return _balance[account];
    }

    /**
     * @dev Start round of ACPI ending the last one.
     */
    function startRound() public override onlyOwner returns (bool) {}


    /**
     * @dev Returns the average value for target ACPI will be 0 until acpi end
     */
    function acpiPrice() public override view returns (uint256) {
        return _acpiPrice;
    }
}