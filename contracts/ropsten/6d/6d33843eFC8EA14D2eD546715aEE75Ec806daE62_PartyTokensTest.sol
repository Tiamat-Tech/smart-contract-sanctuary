// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PartyTokensTest is ERC20, Ownable {
    uint256 limit;
    mapping (address => uint) timeouts;
    
    constructor() ERC20("PolkaParty (test)", "POLP") {
        limit = 10000 * 10 ** decimals();
        _mint(msg.sender, limit);
    }

    function changeLimit(uint256 _l) public onlyOwner {
        limit = _l;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    //  Only allows to request funds every 30 mintues
    function requestFunds() external{
        require(timeouts[msg.sender] <= block.timestamp - 30 minutes, "You can only withdraw once every 30 minutes. Please check back later.");
        _mint(msg.sender, limit);
        timeouts[msg.sender] = block.timestamp;
    }
}