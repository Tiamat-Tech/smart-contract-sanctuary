// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Token is ERC20, Ownable {
    uint public immutable maxSupply;
    constructor(string memory _name, string memory _symbol) ERC20 (_name, _symbol){
        _mint(msg.sender, 10000*10**18);
        maxSupply = 10000*10**18;
    }

    function mint(address account, uint amount) public onlyOwner {
        require(amount <= maxSupply - totalSupply(), "minting more than maxSupply" );
        _mint(account, amount);
    }

    function burn(address account, uint amount) public onlyOwner  {
        _burn(account, amount);
    }
}