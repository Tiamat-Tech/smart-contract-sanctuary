// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is ERC20, AccessControl {
    uint8 private _decimals;
    bytes32 public MINTER_ROLE = "MINTER_ROLE";
    bytes32 public BURNER_ROLE = "BURNER_ROLE";

    constructor(string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        _decimals = decimals_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function mint(address to, uint amount) public onlyMinter {
        _mint(to, amount);
    }

    function burn(address to, uint amount) public onlyBurner {
        _burn(to, amount);
    }

    modifier onlyMinter {
        require(hasRole(MINTER_ROLE, msg.sender), "Token: caller is not minter");
        _;
    }

    modifier onlyBurner {
        require(hasRole(BURNER_ROLE, msg.sender), "Token: caller is not burner");
        _;
    }

}