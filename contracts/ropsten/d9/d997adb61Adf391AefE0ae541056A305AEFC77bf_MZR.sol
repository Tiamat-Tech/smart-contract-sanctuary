// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

contract MZR is ERC20{
    constructor() public ERC20("Mizar", "MZR") {
        uint256 _totalSupply = 10_000_000_000 * 10**18;
        address _devFund = 0x2D6d7BEa65dA1154faCE55f34e06DA753C34cECf;
        address _teamFund = 0x717C49bcDCc18B1D093e447cabA87594640Bc3B5;
        _mint(msg.sender, _totalSupply);
        transfer(_devFund, _totalSupply * 20 / 100);
        transfer(_teamFund, _totalSupply * 80 / 100);
    }
    
    function burn(uint amount) external {
        _burn(msg.sender, amount);
    }
}