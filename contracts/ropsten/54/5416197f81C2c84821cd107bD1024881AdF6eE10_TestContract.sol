pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestContract is ERC1155 {
    uint256 public airlineCount;

    constructor() public ERC1155("") {}
    
    function addNewAirline(uint256 initialSupply) public {
        airlineCount++;
        uint256 airlineTokenClassId = airlineCount;
        _mint(msg.sender, airlineTokenClassId, initialSupply, "");
    }

}