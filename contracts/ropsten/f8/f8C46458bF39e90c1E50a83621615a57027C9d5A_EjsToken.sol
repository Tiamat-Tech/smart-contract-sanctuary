// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./interfaces/IEjsToken.sol";

contract EjsToken is ERC20Capped, IEjsToken {
    address public governanceAccount;
    address public minterAccount;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 tokenCap
    ) ERC20(tokenName, tokenSymbol) ERC20Capped(tokenCap) {
        governanceAccount = msg.sender;
        minterAccount = msg.sender;
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
        override
        onlyBy(governanceAccount)
    {
        require(account != address(0), "EjsToken: zero governance account");

        governanceAccount = account;
    }

    function setMinterAccount(address account)
        external
        override
        onlyBy(governanceAccount)
    {
        require(account != address(0), "EjsToken: zero minter account");
        minterAccount = account;
    }
}