// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import "./library/Xrc20Token.sol";

contract TokenFactory {
    address private _owner;
    mapping(address => Xrc20Token[]) public deployedContracts;

    constructor()
    {
        _owner = msg.sender;
    }

    modifier onlyOwner() 
    {
        require (msg.sender == _owner, "Only allow the owner run this function!");
        _;
    }

    function createToken(
        address _token_Owner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialBalance,
        string memory _tokenURI,
        string memory _iconURI
        ) external
    {

        Xrc20Token t = new Xrc20Token(_token_Owner, _name, _symbol, _decimals, _initialBalance, _tokenURI, _iconURI);
        deployedContracts[msg.sender].push(t);
    }
}