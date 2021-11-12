// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./interfaces/IVestingFactory.sol";

contract VestingProxy is ERC1967Proxy {
  /**
   * @dev Storage slot with the factory of the contract.
   * This is the keccak-256 hash of "co.coinvise.vesting.factory" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 private constant _FACTORY_SLOT = 0x686e735ce73530783b820ca8572edf93cf34287a2d41fef1bb10afc46d73ce74;

  modifier onlyVestingFactory() {
    require(msg.sender == _factory(), "ERR__UNAUTHORIZED");
    _;
  }
  
  constructor(
    address _vesting,
    bytes memory _data
  ) ERC1967Proxy(_vesting, _data) {
    assert(_FACTORY_SLOT == bytes32(uint256(keccak256("co.coinvise.vesting.factory")) - 1));
    require(IVestingFactory(msg.sender).vesting() != address(0));
    _setFactory(msg.sender);
  }

  function vesting() public view returns (address) {
    return _implementation();
  }

  function vestingFactory() public view returns (address factory_) {
    factory_ = _factory();
  }

  /**
   * @dev Returns the current factory.
   */
  function _factory() internal view returns (address factory) {
    bytes32 slot = _FACTORY_SLOT;
    assembly {
      factory := sload(slot)
    }
  }

  /**
   * @dev Stores a new address in the EIP1967 factory slot.
   */
  function _setFactory(address factory) private {
    bytes32 slot = _FACTORY_SLOT;

    assembly {
      sstore(slot, factory)
    }
  }

  function upgradeVesting(address _vesting) public onlyVestingFactory {
    _upgradeTo(_vesting);
  }
}