// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./ICryptoOwl.sol";
import "./ICryptoOwlGuardian.sol";

contract CryptoOwlGuardian is Ownable, ICryptoOwlGuardian {
    using Address for address;

    ICryptoOwl cryptoOwl;

    mapping(address => bool) public custodians;
    mapping(address => bool) public governors;
    mapping(address => bool) public guardians;

    /**
     * @notice Ensure that the current caller is a guardian
     */
    modifier onlyGuardian() {
        require(guardians[_msgSender()], "CryptoOwlGuardian: not a guardian");
        _;
    }

    /**
     * @notice Ensure that the current caller is a governor
     */
    modifier onlyGovernor() {
        require(governors[_msgSender()], "CryptoOwlGuardian: not a governor");
        _;
    }

    /**
     * @notice Ensure that the current caller is a governor or guardian
     */
    modifier onlyGovernorOrGuardian() {
        require(
            governors[_msgSender()] || guardians[_msgSender()],
            "CryptoOwlGuardian: not a governor"
        );
        _;
    }

    /**
     * @notice Ensure that the current caller is a custodian
     */
    modifier onlyCustodian() {
        require(custodians[_msgSender()], "CryptoOwlGuardian: not a custodian");
        _;
    }

    function setCryptoOwlContract(address cocAddress) external override onlyOwner {
        require(
            cocAddress.isContract(),
            "CryptoOwlGuardian: invalid contract address"
        );
        cryptoOwl = ICryptoOwl(cocAddress);
    }

    function addCustodian(address custodian)
        external
        override
        onlyGovernorOrGuardian
    {
        require(
            custodian != address(0),
            "CryptoOwlGuardian: custodian should not be 0 address"
        );
        custodians[custodian] = true;
        emit CustodianAdded(custodian);
    }

    function addGovernor(address governor) external override onlyGuardian {
        require(
            governor != address(0),
            "CryptoOwlGuardian: governor should not be 0 address"
        );
        governors[governor] = true;
        emit GovernorAdded(governor);
    }

    function addGuardian(address guardian) external override onlyOwner {
        require(
            guardian != address(0),
            "CryptoOwlGuardian: guardian should not be 0 address"
        );
        guardians[guardian] = true;
        emit GuardianAdded(guardian);
    }

    function removeCustodian(address custodian)
        external
        override
        onlyGovernorOrGuardian
    {
        custodians[custodian] = false;
        emit CustodianRemoved(custodian);
    }

    function removeGovernor(address governor) external override onlyGuardian {
        governors[governor] = false;
        emit GovernorRemoved(governor);
    }

    function removeGuardian(address guardian) external override onlyOwner {
        guardians[guardian] = false;
        emit GuardianRemoved(guardian);
    }

    function isCustodian(address custodian)
        external
        view
        override
        returns (bool)
    {
        return custodians[custodian];
    }

    function isGovernor(address governor)
        external
        view
        override
        returns (bool)
    {
        return governors[governor];
    }

    function isGuardian(address guardian)
        external
        view
        override
        returns (bool)
    {
        return guardians[guardian];
    }
}