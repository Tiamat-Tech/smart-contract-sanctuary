pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./DevitaId.sol";

contract DevitaIdFactory {
  address public devitaIdMaster;
  mapping(address => bool) public hasMinted;
  address private owner;

  event DevitaIdCreated(address indexed newAddress);

  constructor(address _master, address _owner) {
    devitaIdMaster = _master;
    owner = _owner;
  }

  function createToken(bytes32 salt) external {
    require(
      !hasMinted[msg.sender],
      "DevitaId contract can only be minted once"
    );
    address newToken = Clones.cloneDeterministic(devitaIdMaster, salt);
    DevitaId(newToken).initialize(
      msg.sender,
      owner,
      "https://devita.com/api/id/{id}.json"
    );
    emit DevitaIdCreated(newToken);
    hasMinted[msg.sender] = true;
  }

  function getTokenAddress(bytes32 salt) external view returns (address) {
    return Clones.predictDeterministicAddress(devitaIdMaster, salt);
  }
}