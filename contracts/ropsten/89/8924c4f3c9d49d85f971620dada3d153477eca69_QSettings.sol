// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @author fantasy
 * Owner(Manager) is the DAO address who will manage Quiver Protocol
 */
contract QSettings is OwnableUpgradeable {
    // events
    event SetFoundationWallet(address indexed owner, address wallet);

    // QStk contract address
    address public qstk;
    // foundation
    address public foundation; // periodically sends FOUNDATION_PERCENTAGE % of deposits to foundation wallet.

    function initialize(address _qstk, address _foundation)
        external
        initializer
    {
        __Ownable_init();

        qstk = _qstk;
        foundation = _foundation;
    }

    /**
     * @dev manager is the DAO address who will manager Quiver Protocol
     */
    function manager() external view returns (address) {
        return owner();
    }

    /**
     * @dev sets the foundation wallet
     */
    function setFoundation(address _foundation) external onlyOwner {
        foundation = _foundation;

        emit SetFoundationWallet(msg.sender, _foundation);
    }
}