// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TokenFactory is AccessControl {
    using SafeERC20 for IERC20;
    using Address for address;

    bytes32 public constant FACTORY_MANAGER = keccak256("FACTORY_MANAGER");
    bytes32 internal constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 internal constant UPGRADE_MANAGER_ROLE = keccak256("UPGRADE_MANAGER_ROLE");

    event Deploy(address indexed owner, address tokenProxy);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FACTORY_MANAGER, _msgSender());
    }


    function deployToken(
        address tokenInstance,
        address governance,
        bytes calldata tokenInitializerCall
    ) external {


        address tokenProxy = address(new ERC1967Proxy(tokenInstance, tokenInitializerCall));
        uint256 balance = IERC20(tokenProxy).balanceOf(address(this));
        IERC20(tokenProxy).safeTransfer(_msgSender(), balance);

        AccessControl(tokenProxy).grantRole(UPGRADE_MANAGER_ROLE, _msgSender());
        AccessControl(tokenProxy).renounceRole(UPGRADE_MANAGER_ROLE, address(this));
        AccessControl(tokenProxy).grantRole(GOVERNANCE_ROLE, governance);
        AccessControl(tokenProxy).renounceRole(GOVERNANCE_ROLE, address(this));
        AccessControl(tokenProxy).grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        AccessControl(tokenProxy).renounceRole(DEFAULT_ADMIN_ROLE, address(this));

        emit Deploy(_msgSender(), tokenProxy);
    }


}