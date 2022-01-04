// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./Taxi.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Verifier {
  address private deployer;

  function initialize(address _deployer) public {
    require(deployer == address(0), "Already initialized");
    deployer = _deployer;
  }

  // 1. Get bytecode of contract to be deployed
  function getBytecode(address _guildAddress)
    private
    pure
    returns (bytes memory)
  {
    bytes memory bytecode = type(Taxi).creationCode;

    return abi.encodePacked(bytecode, abi.encode(_guildAddress));
  }

  // 2. Compute the address of the contract to be deployed
  // NOTE: _salt is a random number used to create an address
  function getAddress(address _guildAddress) public view returns (address) {
    bytes memory bytecode = getBytecode(_guildAddress);
    uint256 salt = 0;
    bytes32 hash = keccak256(
      abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(bytecode))
    );

    // NOTE: cast last 20 bytes of hash to address
    return address(uint160(uint256(hash)));
  }
}