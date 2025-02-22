// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import '../../dependencies/openzeppelin/contracts/Address.sol';
import '../../dependencies/openzeppelin/upgradeability/BaseUpgradeabilityProxy.sol';
import './IProxy.sol';

/// @dev This contract is a transparent upgradeability proxy with admin. The admin role is immutable.
contract TransparentProxy is BaseUpgradeabilityProxy, IProxy {
  address internal immutable ADMIN;

  constructor(
    address admin,
    address logic,
    bytes memory data
  ) {
    require(admin != address(0));
    ADMIN = admin;
    initialize(logic, data);
  }

  modifier ifAdmin() {
    if (msg.sender == ADMIN) {
      _;
    } else {
      _fallback();
    }
  }

  /// @return impl The address of the implementation.
  function implementation() external ifAdmin returns (address impl) {
    return _implementation();
  }

  /// @dev Upgrade the backing implementation of the proxy and call a function on it.
  function upgradeToAndCall(address logic, bytes calldata data) external payable override ifAdmin {
    _upgradeTo(logic);
    Address.functionDelegateCall(logic, data);
  }

  /// @dev Only fall back when the sender is not the admin.
  function _willFallback() internal virtual override {
    require(msg.sender != ADMIN, 'Cannot call fallback function from the proxy admin');
    super._willFallback();
  }

  function initialize(address logic, bytes memory data) private {
    require(_implementation() == address(0));
    assert(IMPLEMENTATION_SLOT == bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
    _setImplementation(logic);
    if (data.length > 0) {
      Address.functionDelegateCall(logic, data);
    }
  }
}