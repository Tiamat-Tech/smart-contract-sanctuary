// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./Taxi.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Verifier is Ownable {
  address public deployer;

  function setDeployer(address _deployer) public onlyOwner {
    deployer = _deployer;
  }

  // 1. Get bytecode of contract to be deployed
  function getBytecode(address _guildAddress)
    public
    pure
    returns (bytes memory)
  {
    bytes memory bytecode = type(Taxi).creationCode;

    return abi.encodePacked(bytecode, abi.encode(_guildAddress));
  }

  // 2. Compute the address of the contract to be deployed
  // NOTE: _salt is a random number used to create an address
  function getAddress(bytes memory bytecode, uint256 _salt)
    public
    view
    returns (address)
  {
    bytes32 hash = keccak256(
      abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
    );

    // NOTE: cast last 20 bytes of hash to address
    return address(uint160(uint256(hash)));
  }
}