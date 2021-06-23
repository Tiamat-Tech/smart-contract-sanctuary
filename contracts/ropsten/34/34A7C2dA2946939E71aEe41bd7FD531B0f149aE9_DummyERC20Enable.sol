//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";

contract DummyERC20Enable is ERC20, ERC165 {

    bool public swapAndLiquifyEnabled = true;
    bool public tradingEnabled = false;

    event Ban(
        address indexed account
    );

    event EnabledTrade(
        bool indexed status
    );

    constructor() ERC20("DummyERC20Enable", "DE") {
        _registerInterface(type(IERC20).interfaceId);
    }

    function mint(address receiver, uint256 supply) external {
        _mint(receiver, supply);
    }

    function excludeAccount(address account) external {
        emit Ban(account);
    }

    function addBot(address account) external {
        emit Ban(account);
    }
    
    function enableTrading(bool _tradingEnabled) external {
        tradingEnabled = _tradingEnabled;
        emit EnabledTrade(_tradingEnabled);
    }


}