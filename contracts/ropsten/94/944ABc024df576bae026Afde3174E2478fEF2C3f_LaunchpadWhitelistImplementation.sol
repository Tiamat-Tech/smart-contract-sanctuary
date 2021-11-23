// SPDX-License-Identifier: Apache-2.0
// Copyright 2021 Enjinstarter
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "./interfaces/ILaunchpadWhitelistImplementation.sol";

/**
 * @title LaunchpadWhitelistImplementation
 * @author Enjinstarter
 */
contract LaunchpadWhitelistImplementation is
    Initializable,
    ILaunchpadWhitelistImplementation
{
    uint256 public constant BATCH_MAX_NUM = 200;

    address private _governanceAccount;
    address private _adminAccount;

    mapping(address => uint256) private _whitelisteds;

    function initialize(address governanceAccount_, address adminAccount_)
        public
        initializer
    {
        require(
            governanceAccount_ != address(0),
            "LaunchpadWhitelistImplementation: zero governance account"
        );

        require(
            adminAccount_ != address(0),
            "LaunchpadWhitelistImplementation: zero admin account"
        );

        _governanceAccount = governanceAccount_;
        _adminAccount = adminAccount_;
    }

    modifier onlyBy(address account) {
        require(
            msg.sender == account,
            "LaunchpadWhitelistImplementation: sender unauthorized"
        );
        _;
    }

    function addWhitelisted(address account, uint256 amount)
        external
        override
        onlyBy(_adminAccount)
    {
        _addWhitelisted(account, amount);
    }

    function removeWhitelisted(address account)
        external
        override
        onlyBy(_adminAccount)
    {
        _removeWhitelisted(account);
    }

    function addWhitelistedBatch(
        address[] memory accounts,
        uint256[] memory amounts
    ) external override onlyBy(_adminAccount) {
        require(accounts.length > 0, "LaunchpadWhitelistImplementation: empty");
        require(
            accounts.length <= BATCH_MAX_NUM,
            "LaunchpadWhitelistImplementation: exceed max"
        );
        require(
            amounts.length == accounts.length,
            "LaunchpadWhitelistImplementation: different length"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            _addWhitelisted(accounts[i], amounts[i]);
        }
    }

    function removeWhitelistedBatch(address[] memory accounts)
        external
        override
        onlyBy(_adminAccount)
    {
        require(accounts.length > 0, "LaunchpadWhitelistImplementation: empty");
        require(
            accounts.length <= BATCH_MAX_NUM,
            "LaunchpadWhitelistImplementation: exceed max"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            _removeWhitelisted(accounts[i]);
        }
    }

    function setGovernanceAccount(address account)
        external
        onlyBy(_governanceAccount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );

        _governanceAccount = account;
    }

    function setAdminAccount(address account)
        external
        onlyBy(_governanceAccount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );

        _adminAccount = account;
    }

    function isWhitelisted(address account)
        external
        view
        override
        returns (bool isWhitelisted_)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );

        isWhitelisted_ = _whitelisteds[account] > 0;
    }

    function whitelistedAmountFor(address account)
        external
        view
        override
        returns (uint256 whitelistedAmount)
    {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );

        whitelistedAmount = _whitelisteds[account];
    }

    function governanceAccount()
        external
        view
        returns (address goveranceAccount_)
    {
        goveranceAccount_ = _governanceAccount;
    }

    function adminAccount() external view returns (address adminAccount_) {
        adminAccount_ = _adminAccount;
    }

    function _addWhitelisted(address account, uint256 amount) internal {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );
        require(amount > 0, "LaunchpadWhitelistImplementation: zero amount");
        require(
            _whitelisteds[account] == 0,
            "LaunchpadWhitelistImplementation: already whitelisted"
        );

        _whitelisteds[account] = amount;

        emit WhitelistedAdded(account, amount);
    }

    function _removeWhitelisted(address account) internal {
        require(
            account != address(0),
            "LaunchpadWhitelistImplementation: zero account"
        );
        require(
            _whitelisteds[account] > 0,
            "LaunchpadWhitelistImplementation: not whitelisted"
        );

        _whitelisteds[account] = 0;

        emit WhitelistedRemoved(account);
    }
}