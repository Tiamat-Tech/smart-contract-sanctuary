// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import '@openzeppelin/contracts/proxy/Clones.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './SeemsLegitNFT.sol';

contract SeemsLegitFactory is Ownable {
    address immutable implementationAddress;

    constructor() {
        implementationAddress = address(new SeemsLegitNFT());
    }

    function createCollection(string calldata name, uint256 price) onlyOwner external returns (address) {
        address clone = Clones.clone(implementationAddress);
        SeemsLegitNFT(clone).initialize(name, price, owner());
        return clone;
    }

    function getImplementationAddress() public view returns(address) {
        return implementationAddress;
    }
}