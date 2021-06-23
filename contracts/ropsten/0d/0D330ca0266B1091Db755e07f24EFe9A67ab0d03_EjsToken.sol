// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./interfaces/IEjsToken.sol";

contract EjsToken is ERC20Capped, IEjsToken {
    address public governanceAccount;
    address public minterAccount;
    address public teamAccount;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 tokenCap,
        address teamAccount_,
        uint256 teamAmount
    ) ERC20(tokenName, tokenSymbol) ERC20Capped(tokenCap) {
        require(teamAccount_ != address(0), "EjsToken: zero team account");
        require(teamAmount > 0, "EjsToken: zero team amount");

        governanceAccount = msg.sender;
        minterAccount = msg.sender;
        teamAccount = teamAccount_;

        _mint(teamAccount_, teamAmount);
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "EjsToken: sender unauthorized");
        _;
    }

    function mint(address account, uint256 amount)
        external
        override
        onlyBy(minterAccount)
    {
        require(amount > 0, "EjsToken: zero amount");
        _mint(account, amount);
    }

    function setGovernanceAccount(address account)
        external
        onlyBy(governanceAccount)
    {
        require(account != address(0), "EjsToken: zero governance account");

        governanceAccount = account;
    }

    function setMinterAccount(address account)
        external
        onlyBy(governanceAccount)
    {
        require(account != address(0), "EjsToken: zero minter account");
        minterAccount = account;
    }
}