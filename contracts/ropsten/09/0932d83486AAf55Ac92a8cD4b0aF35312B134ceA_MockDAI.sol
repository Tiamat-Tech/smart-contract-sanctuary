// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMockMinter {
    function mint(address account, uint256 amount) external;
}

contract MockDAI is ERC20, IMockMinter {
    constructor() ERC20("Dai Stablecoin", "DAI") {
    }

    function mint(address account, uint256 amount) external override {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}

contract MockUSDC is ERC20, IMockMinter {
    constructor() ERC20("USD Coin", "USDC") {
    }

    function decimals() public override view virtual returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) external override {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}

contract MockUSDT is ERC20, IMockMinter {
    constructor() ERC20("Tether USD", "USDT") {
    }

    function decimals() public override view virtual returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) external override {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}

contract MockTUSD is ERC20, IMockMinter {
    constructor() ERC20("TrueUSD", "TUSD") {
    }

    function mint(address account, uint256 amount) external override {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }
}