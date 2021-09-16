// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CareToken is ERC20 {

  address public owner;
  address public SOPV1Contract;

  constructor() ERC20('Spirit Orb Pets Care Token', 'CARE') {
    _mint(msg.sender, 1000000000 * 10 ** 18);
    owner = msg.sender;
    SOPV1Contract = address(0);
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  function mintMoreToContract(uint256 amount) external onlyOwner {
    _mint(SOPV1Contract, amount * 10 ** 18);
  }

  function setOwner(address _address) external onlyOwner {
    owner = _address;
  }

  function setSOPV1ContractAddress(address _address) external onlyOwner {
    require(SOPV1Contract == address(0), "This can only be set once!");
    SOPV1Contract = _address;
  }

}