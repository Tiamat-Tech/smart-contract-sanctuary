//SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is ERC20, AccessControl {
    uint256 public INIT_AMOUNT = 100 * 10**6 * 10**18;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _mint(_msgSender(), INIT_AMOUNT);
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: ADMIN role required");
        _;
    }

    function mint(address beneficiary, uint256 amount) public onlyAdmin {
        _mint(beneficiary, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}