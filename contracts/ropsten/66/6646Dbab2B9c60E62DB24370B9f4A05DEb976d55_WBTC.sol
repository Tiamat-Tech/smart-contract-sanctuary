// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MockBTC is ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        address admin,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public ERC20(name, symbol) {
        _setupDecimals(decimals);

        _setupRole(DEFAULT_ADMIN_ROLE, admin);

        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function mint(address account, uint256 amount) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "require minter role");

        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }
}

contract WBTC is MockBTC {
    constructor(address admin) public MockBTC(admin, "Wrapped Bitcoin", "WBTC", 8) {}
}

contract HBTC is MockBTC {
    constructor(address admin) public MockBTC(admin, "Huobi BTC", "HBTC", 18) {}
}

contract OtherCoin is MockBTC {
    constructor(address admin) public MockBTC(admin, "Other ERC20", "OTHER", 18) {}
}