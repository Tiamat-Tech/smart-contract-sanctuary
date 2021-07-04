// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./interfaces/IEjsToken.sol";

contract EjsToken is ERC20Capped, IEjsToken {
    uint256 public constant GROUPS_MAX_NUM = 50;

    address public governanceAccount;
    address public minterAccount;

    // https://github.com/crytic/slither/wiki/Detector-Documentation#variable-names-are-too-similar
    // slither-disable-next-line similar-names
    address[] private _premintAccounts;
    // slither-disable-next-line similar-names
    mapping(address => uint256) private _premintAmounts;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 tokenCap,
        address[] memory premintAccounts_,
        uint256[] memory premintAmounts_
    ) ERC20(tokenName, tokenSymbol) ERC20Capped(tokenCap) {
        require(
            premintAccounts_.length <= GROUPS_MAX_NUM,
            "EjsToken: exceed max"
        );
        require(
            premintAccounts_.length == premintAmounts_.length,
            "EjsToken: Mismatch in number of premint accounts and amounts"
        );

        governanceAccount = msg.sender;
        minterAccount = msg.sender;

        for (uint256 i = 0; i < premintAccounts_.length; i++) {
            address premintAccount = premintAccounts_[i];
            uint256 premintAmount = premintAmounts_[i];
            require(
                premintAccount != address(0),
                "EjsToken: zero premint account"
            );
            require(premintAmount > 0, "EjsToken: zero premint amount");
            _premintAmounts[premintAccount] = premintAmount;

            _mint(premintAccount, premintAmount);
        }

        _premintAccounts = premintAccounts_;
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

    function premintAccounts()
        external
        view
        override
        returns (address[] memory premintAccounts_)
    {
        premintAccounts_ = _premintAccounts;
    }

    function premintAmountFor(address account)
        external
        view
        override
        returns (uint256 premintAmount_)
    {
        require(account != address(0), "EjsToken: zero account");

        premintAmount_ = _premintAmounts[account];
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