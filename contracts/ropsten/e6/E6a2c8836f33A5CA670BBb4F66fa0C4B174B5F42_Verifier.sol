// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./Taxi.sol";

contract Verifier {
    address private deployer;

    constructor(address _deployer) public {
        deployer = _deployer;
    }

    // Compute the address of the contract based on bytecode + constructor
    function getAddress(address guildAddress) public view returns (address) {
        bytes memory bytecode = type(Taxi).creationCode;

        bytes memory initCode = abi.encodePacked(
            bytecode,
            abi.encode(guildAddress)
        );

        uint256 salt = 0;
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(initCode))
        );

        return address(uint160(uint256(hash)));
    }
}