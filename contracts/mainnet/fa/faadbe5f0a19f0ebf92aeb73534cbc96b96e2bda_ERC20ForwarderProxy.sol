// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ERC20ForwarderStorage.sol";
import "../libs/Ownable.sol";

/**
 * @title Proxy
 * @dev Implements delegation of calls to other contracts, with proper
 * forwarding of return values and bubbling of failures.
 * It defines a fallback function that delegates all calls to the address
 * returned by the abstract _implementation() internal function.
 */
 
abstract contract Proxy {
  /**
   * @dev Fallback function.
   * Implemented entirely in `_fallback`.
   */
  fallback() payable external {
    _fallback();
  }
  
  /**
   * @return The Address of the implementation.
   */
  function _implementation() internal virtual view returns (address);
  
   /**
   * @dev Delegates execution to an implementation contract.
   * This is a low level function that doesn't return to its internal call site.
   * It will return to the external caller whatever the implementation returns.
   * @param implementation Address to delegate.
   */
  function _delegate(address implementation) internal {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
      // delegatecall returns 0 on error.
      case 0 { revert(0, returndatasize()) }
      default { return(0, returndatasize()) }
    }
  }
  
  
  /**
   * @dev Function that is run as the first thing in the fallback function.
   * Can be redefined in derived contracts to add functionality.
   * Redefinitions must call super._willFallback().
   */
  function _willFallback() virtual internal {
  }

  /**
   * @dev fallback implementation.
   * Extracted to enable manual triggering.
   */
  function _fallback() internal {
    _willFallback();
    _delegate(_implementation());
  }
 
}

// File: openzeppelin-solidity/contracts/AddressUtils.sol

/**
 * Utility library of inline functions on addresses
 */
library AddressUtils {

  /**
   * Returns whether the target address is a contract
   * @dev This function will return false if invoked during the constructor of a contract,
   * as the code is not actually created until after the constructor finishes.
   * @param addr address to check
   * @return whether the target address is a contract
   */
  function isContract(address addr) internal view returns (bool) {
    uint256 size;
    // XXX Currently there is no better way to check if there is a contract in an address
    // than to check the size of the code at that address.
    // See https://ethereum.stackexchange.com/a/14016/36603
    // for more details about how this works.
    // TODO Check this again before the Serenity release, because all addresses will be
    // contracts then.
    // solium-disable-next-line security/no-inline-assembly
    assembly { size := extcodesize(addr) }
    return size > 0;
  }

}


/**
 * @title UpgradeabilityProxy
 * @dev This contract implements a proxy that allows to change the
 * implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract UpgradeabilityProxy is Proxy {
  /**
   * @dev Emitted when the implementation is upgraded.
   * @param implementation Address of the new implementation.
   */
  event Upgraded(address implementation);

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "io.biconomy.ercfeeproxy.implementation", and is
   * validated in the constructor.
   */
  bytes32 private constant IMPLEMENTATION_SLOT = 0x0b63f4b9f11e5ae2112641c92ed865d24a316fbdf51bbd102721d37df8b1f8e7;

  /**
   * @dev Contract constructor.
   * @param _implementation Address of the initial implementation.
   */
  constructor(address _implementation) public {
    assert(IMPLEMENTATION_SLOT == keccak256("io.biconomy.ercfeeproxy.implementation"));

    _setImplementation(_implementation);
  }

  /**
   * @dev Returns the current implementation.
   */
  function _implementation() internal override view returns (address impl) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
      impl := sload(slot)
    }
  }

  /**
   * @dev Upgrades the proxy to a new implementation.
   * @param newImplementation Address of the new implementation.
   */
  function _upgradeTo(address newImplementation) internal {
    _setImplementation(newImplementation);
    emit Upgraded(newImplementation);
  }

  /**
   * @dev Sets the implementation address of the proxy.
   * @param newImplementation Address of the new implementation.
   */
  function _setImplementation(address newImplementation) private {
    require(AddressUtils.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

    bytes32 slot = IMPLEMENTATION_SLOT;

    assembly {
      sstore(slot, newImplementation)
    }
  }
  
}


// File: zos-lib/contracts/upgradeability/AdminUpgradeabilityProxy.sol

/**
 * @title AdminUpgradeabilityProxy
 * @dev This contract combines an upgradeability proxy with an authorization
 * mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the
 * `ifAdmin` modifier. See ethereum/solidity#3864 for a Solidity
 * feature proposal that would enable this to be done automatically.
 */
contract AdminUpgradeabilityProxy is UpgradeabilityProxy {
  /**
   * @dev Emitted when the administration has been transferred.
   * @param previousAdmin Address of the previous admin.
   * @param newAdmin Address of the new admin.
   */
  event AdminChanged(address previousAdmin, address newAdmin);

  /**
   * @dev Storage slot with the admin of the contract.
   * This is the keccak-256 hash of "io.biconomy.ercfeeproxy.admin", and is
   * validated in the constructor.
   */
  bytes32 private constant ADMIN_SLOT = 0x71d39ddb6ef9c6ab43d46265ce63a4cf0419f6c2e28ab0aa6a80f50f7d56dd54;

  /**
   * @dev Modifier to check whether the `msg.sender` is the admin.
   * If it is, it will run the function. Otherwise, it will delegate the call
   * to the implementation.
   */
  modifier ifAdmin() {
    if (msg.sender == _admin()) {
      _;
    } else {
      _fallback();
    }
  }

  /**
   * Contract constructor.
   * It sets the `msg.sender` as the proxy administrator.
   * @param _implementation address of the initial implementation.
   */
  constructor(address _implementation, address _admin) UpgradeabilityProxy(_implementation) public {
    require(
        _admin != address(0),
        "admin address cannot be zero"
       );
    assert(ADMIN_SLOT == keccak256("io.biconomy.ercfeeproxy.admin"));
    _setAdmin(_admin);
  }

  /**
   * @return The address of the proxy admin.
   */
  function admin() external view returns (address) {
    return _admin();
  }

  /**
   * @return The address of the implementation.
   */
  function implementation() external view returns (address) {
    return _implementation();
  }

  /**
   * @dev Changes the admin of the proxy.
   * Only the current admin can call this function.
   * @param newAdmin Address to transfer proxy administration to.
   */
  function changeAdmin(address newAdmin) external ifAdmin {
    require(newAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
    emit AdminChanged(_admin(), newAdmin);
    _setAdmin(newAdmin);
  }

  /**
   * @dev Upgrade the backing implementation of the proxy.
   * Only the admin can call this function.
   * @param newImplementation Address of the new implementation.
   */
  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeTo(newImplementation);
  }

  /**
   * @dev Upgrade the backing implementation of the proxy and call a function
   * on the new implementation.
   * This is useful to initialize the proxied contract.
   * @param newImplementation Address of the new implementation.
   * @param data Data to send as msg.data in the low level call.
   * It should include the signature and the parameters of the function to be
   * called, as described in
   * https://solidity.readthedocs.io/en/develop/abi-spec.html#function-selector-and-argument-encoding.
   */
  function upgradeToAndCall(address newImplementation, bytes calldata data) payable external ifAdmin {
    _upgradeTo(newImplementation);
    bool success;
    bytes memory ret;
    (success,ret) = address(this).call{value : msg.value}(abi.encodePacked(data));
    require(success,"call to new implementation did not succeed");
  }

  /**
   * @dev returns The admin slot.
   */
  function _admin() internal view returns (address adm) {
    bytes32 slot = ADMIN_SLOT;
    assembly {
      adm := sload(slot)
    }
  }

  /**
   * @dev Sets the address of the proxy admin.
   * @param newAdmin Address of the new proxy admin.
   */
  function _setAdmin(address newAdmin) internal {
    bytes32 slot = ADMIN_SLOT;

    assembly {
      sstore(slot, newAdmin)
    }
  }

  /**
   * @dev Only fall back when the sender is not the admin.
   */
  function _willFallback() internal override {
    require(msg.sender != _admin(), "Cannot call fallback function from the proxy admin");
    super._willFallback();
  }
}

/**
 * @title ERC20ForwarderProxy
 * @dev This contract proxies ERC20Forwarder calls and enables ERC20Forwarder upgrades
*/ 
contract ERC20ForwarderProxy is AdminUpgradeabilityProxy, Ownable, ERC20ForwarderStorage  {
    constructor(address _implementation, address _admin, address _owner) public AdminUpgradeabilityProxy(_implementation, _admin) Ownable(_owner) {
      require(
         _owner != address(0),
        "_owner cannot be zero"
       );
    }
}