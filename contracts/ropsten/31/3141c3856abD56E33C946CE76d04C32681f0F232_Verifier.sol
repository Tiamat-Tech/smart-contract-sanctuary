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

  // Compute the address of the contract based on bytecode + constructor
  function getAddress(address _guildAddress) public view returns (address) {
    bytes memory bytecode = type(Taxi).creationCode;

    bytes memory initCode = abi.encodePacked(
      bytecode,
      abi.encode(_guildAddress)
    );

    uint256 salt = 0;
    bytes32 hash = keccak256(
      abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(initCode))
    );

    return address(uint160(uint256(hash)));
  }
}