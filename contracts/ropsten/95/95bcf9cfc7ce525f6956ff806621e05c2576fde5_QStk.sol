// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/**
 * Quiver Stock Contract
 * @author fantasy
 *
 * initial supply on contact creation.
 * blacklisted users can't make any action and QStk balance.
 *
 * only minters can mint tokens - owner should be able to add/remove minters. (Minters should be be invester contracts.)
 * owner should be multisig address of governance after initial setup.
 * anyone can burn his/her tokens.
 */

contract QStk is
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    event AddBlacklistedUser(address indexed _user);
    event RemoveBlacklistedUser(address indexed _user);

    mapping(address => bool) public isBlacklisted;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function initialize(uint256 _initialSupply) external initializer {
        __Ownable_init();
        __AccessControlEnumerable_init();
        __ERC20_init("Quiver Stock", "QSTK");
        __ERC20Burnable_init();
        __ERC20Pausable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());

        mint(msg.sender, _initialSupply);
        revokeRole(MINTER_ROLE, msg.sender);
    }

    // minter pauser

    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "QStk: must have minter role to mint"
        );
        _mint(to, amount);
    }

    function pause() public {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "QStk: must have pauser role to pause"
        );
        _pause();
    }

    function unpause() public {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "QStk: must have pauser role to unpause"
        );
        _unpause();
    }

    function addBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] != true, "QStk: already in blacklist");

        isBlacklisted[_user] = true;

        emit AddBlacklistedUser(_user);
    }

    function removeBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] == true, "QStk: not in blacklist");

        isBlacklisted[_user] = false;
        _burn(_user, balanceOf(_user));

        emit RemoveBlacklistedUser(_user);
    }

    function addMinter(address _minter) public onlyOwner {
        _setupRole(MINTER_ROLE, _minter);
    }

    function removeMinter(address _minter) public onlyOwner {
        revokeRole(MINTER_ROLE, _minter);
    }

    // Internal functions

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        if (_from == address(0)) {
            // mint
            require(
                isBlacklisted[_to] != true,
                "QStk: target address is in blacklist"
            );
        } else if (_to == address(0)) {
            // burn
        } else {
            // blacklisted users can't transfer tokens
            require(
                isBlacklisted[_from] != true,
                "QStk: sender address is in blacklist"
            );
            require(
                isBlacklisted[_to] != true,
                "QStk: target address is in blacklist"
            );
            require(_amount != 0, "QStk: non-zero amount is required");
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}