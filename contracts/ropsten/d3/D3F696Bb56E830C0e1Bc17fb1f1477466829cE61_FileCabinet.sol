pragma solidity ^0.8.0;

import "./Will.sol";

contract FileCabinet {
    mapping(address => address[]) public cabinet;

    event NewWill(address will, address benefactor);

    function newWill(address benefactor, address beneficiary, uint256 sealedTime) external {
        Will will = new Will(benefactor, beneficiary, sealedTime);
        cabinet[benefactor].push(address(will));
        emit NewWill(address(will), benefactor);
    }

    function getWills(address benefactor) public view returns (address[] memory) {
        return cabinet[benefactor];
    }
}