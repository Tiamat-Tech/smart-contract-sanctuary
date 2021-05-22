// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interface/IQSettings.sol";

/**
 * @author fantasy
 * Super admin should be the DAO address who will manage Quiver Protocol
 */
contract QSettings is IQSettings, Initializable {
    // events
    event SetAdmin(address indexed admin);
    event SetManager(address indexed executor, address indexed manager);
    event SetFoundationWallet(address indexed foundationWallet);
    event SetFoundation(address indexed foundation);

    // Quiver Manager
    address public admin; // should be the dao address who will set the manager address.
    address public override manager; // manager address who will manage overall Quiver contracts.

    // Quiver Foundation
    address public foundation; // foundation address who can change the foundationWallet address.
    address public override foundationWallet; // periodically sends FOUNDATION_PERCENTAGE % of deposits to foundation wallet.

    // QStk contract address
    address public override qstk;

    modifier onlyAdmin() {
        require(msg.sender == admin, "QSettings: caller is not the admin");
        _;
    }

    modifier onlyFoundation() {
        require(
            msg.sender == foundation,
            "QSettings: caller is not the foundation"
        );
        _;
    }

    function initialize(
        address _admin,
        address _manager,
        address _foundation,
        address _foundationWallet,
        address _qstk
    ) external initializer {
        admin = _admin;
        manager = _manager;
        foundation = _foundation;
        foundationWallet = _foundationWallet;
        qstk = _qstk;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;

        emit SetAdmin(_admin);
    }

    function setManager(address _manager) external {
        require(
            msg.sender == admin || msg.sender == manager,
            "QSettings: caller is not the admin nor manager"
        );

        manager = _manager;

        emit SetManager(msg.sender, _manager);
    }

    function setFoundation(address _foundation) external onlyFoundation {
        foundation = _foundation;

        emit SetFoundation(_foundation);
    }

    function setFoundationWallet(address _foundationWallet)
        external
        onlyFoundation
    {
        foundationWallet = _foundationWallet;

        emit SetFoundationWallet(_foundationWallet);
    }
}