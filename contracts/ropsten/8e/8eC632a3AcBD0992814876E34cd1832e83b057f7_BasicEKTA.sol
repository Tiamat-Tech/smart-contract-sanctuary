// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IEKTAERC20.sol";

contract BasicEKTA is ERC20, AccessControl, IEKTAERC20{

    bytes32 public constant STATE_UPDATER = keccak256("STATE_UPDATER");

    constructor(
        string memory name_,
        string memory symbol_,
        address ektaManager
    ) ERC20(name_, symbol_) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(STATE_UPDATER, ektaManager);
    }

    /*
    @dev only EKTAManager will call this function
    */
    function deposit(address user, uint amount)
    external
    override
    onlyRole(STATE_UPDATER)
    {
        _mint(user, amount);
    }

    /*
    @dev user will withdraw their token using this function
    */
    function withdraw(uint256 amount)
    external
    override
    onlyRole(STATE_UPDATER)
    {
        _burn(_msgSender(), amount);
    }

}