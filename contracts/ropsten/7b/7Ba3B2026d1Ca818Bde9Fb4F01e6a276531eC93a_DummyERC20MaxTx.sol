//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";

contract DummyERC20MaxTx is ERC20, ERC165 {


    uint public _maxTxAmount = 0;
    event Ban(
        address indexed account
    );

    event EnabledTrade(
        bool indexed status
    );

    constructor() ERC20('DummyERC20MaxTx', 'DMTx') {
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

    function setMaxTxPercent(uint256 maxTxPercent) external {
        _maxTxAmount = totalSupply()/100 * maxTxPercent;
        emit EnabledTrade(maxTxPercent > 0);

    }

    function setMaxTx(uint256 amount) external {
        _maxTxAmount = amount;
        emit EnabledTrade(amount > 0);
    }


}