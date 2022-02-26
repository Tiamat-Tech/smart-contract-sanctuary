//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract DaoToken is ERC20, ERC20Permit, ERC20Votes{
    constructor() ERC20("DaoToken", "DAOK") ERC20Permit("DaoToken") {}

    function _afterTokenTransfer(address from, address to, uint amount) internal override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to , amount);
    }

    function _mint(address to, uint amount) internal override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint amount) internal override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}