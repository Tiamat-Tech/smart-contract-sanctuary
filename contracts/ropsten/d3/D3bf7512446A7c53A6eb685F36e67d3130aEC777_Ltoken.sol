// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/ILtoken.sol";

contract Ltoken is ERC20, ILtoken {
    address public governanceAccount;
    address public treasuryPoolAddress;

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {
        governanceAccount = msg.sender;
    }

    modifier onlyBy(address account) {
        require(msg.sender == account, "Ltoken: sender not authorized");
        _;
    }

    function mint(address to, uint256 amount)
        external
        override
        onlyBy(treasuryPoolAddress)
    {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount)
        external
        override
        onlyBy(treasuryPoolAddress)
    {
        _burn(account, amount);
    }

    function setGovernanceAccount(address newGovernanceAccount)
        external
        onlyBy(governanceAccount)
    {
        require(
            newGovernanceAccount != address(0),
            "Ltoken: new governance account is the zero address"
        );

        governanceAccount = newGovernanceAccount;
    }

    function setTreasuryPoolAddress(address newTreasuryPoolAddress)
        external
        onlyBy(governanceAccount)
    {
        require(
            newTreasuryPoolAddress != address(0),
            "Ltoken: new treasury pool address is the zero address"
        );

        treasuryPoolAddress = newTreasuryPoolAddress;
    }

    function _transfer(
        address, /* sender */
        address, /* recipient */
        uint256 /* amount */
    ) internal virtual override {
        // non-transferable between users
        revert("Ltoken: token is non-transferable");
    }
}