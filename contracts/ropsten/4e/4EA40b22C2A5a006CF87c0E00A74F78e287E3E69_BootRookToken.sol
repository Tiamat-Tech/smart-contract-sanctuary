// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

contract BootRookToken is ERC1155 {
    address public governance;
    uint256 public producer;

    modifier onlyGovernance() {
        require(msg.sender == governance, "only governance can call this");

        _;
    }

    constructor(address governance_) public ERC1155("https://game.example/api/item/{id}.json") {
        governance = governance_;
        producer = 0;
    }

    function addNewMusic(uint256 initialSupply) external onlyGovernance {
        producer++;
        uint256 producerTokenClassId = producer;

        _mint(msg.sender, producerTokenClassId, initialSupply, "");
    } 
}