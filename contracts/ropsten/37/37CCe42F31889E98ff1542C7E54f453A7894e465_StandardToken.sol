// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract StandardToken is ERC20Burnable,Ownable{

    uint256 _totalSupply=500 * 10**6 * 10**18;
    uint8 _decimal=18;
    string _name='ByteDex';
    string _symbol='BDX';
    constructor () ERC20(_name, _symbol) {
        //uint mintIndex = _owners.length;
        //_decimal=decimal;
        //_totalSupply=total_supply;
        _mint(msg.sender, _totalSupply);
    }
    function decimals() public view override returns (uint8) {
        return _decimal;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
}