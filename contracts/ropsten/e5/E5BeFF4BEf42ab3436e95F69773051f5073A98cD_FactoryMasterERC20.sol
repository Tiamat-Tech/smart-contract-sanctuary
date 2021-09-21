//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC20/ERC20Burnable.sol";
import "../token/ERC20/ERC20Mintable.sol";
import "../token/ERC20/ERC20MintableBurnable.sol";
import "../token/ERC20/ERC20FixedSupply.sol";
import "../libraries/config-fee.sol";

contract FactoryMasterERC20 {
  ERC20FixedSupply[] private childrenErc20;
  ERC20Mintable[] private childrenErc20Mintable;
  ERC20Burnable[] private childrenErc20Burnable;
  ERC20MintableBurnable[] private childrenErc20MintableBurnable;

  enum Types {
    none,
    erc20,
    erc20Mintable,
    erc20Burnable,
    erc20MintableBurnable
  }

  function createERC20Types(
    Types types,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply,
    uint256 cap
  ) external payable {
    require(
      keccak256(abi.encodePacked((name))) != keccak256(abi.encodePacked(("")))
    );
    require(
      keccak256(abi.encodePacked((symbol))) != keccak256(abi.encodePacked(("")))
    );
    if (types == Types.erc20) {
      require(
        msg.value >= Config.fee_20,
        "ERC20:value must be greater than 0.0001"
      );
      ERC20FixedSupply child = new ERC20FixedSupply(
        msg.sender,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20.push(child);
    }

    if (types == Types.erc20Mintable) {
      require(
        msg.value >= Config.fee_20,
        "ERC20:value must be greater than 0.0001"
      );
      ERC20Mintable child = new ERC20Mintable(
        msg.sender,
        cap,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20Mintable.push(child);
    }

    if (types == Types.erc20Burnable) {
      require(
        msg.value >= Config.fee_20,
        "ERC20:value must be greater than 0.0001"
      );
      ERC20Burnable child = new ERC20Burnable(
        msg.sender,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20Burnable.push(child);
    }

    if (types == Types.erc20MintableBurnable) {
      require(
        msg.value >= Config.fee_20,
        "ERC20:value must be greater than 0.0001"
      );
      ERC20MintableBurnable child = new ERC20MintableBurnable(
        msg.sender,
        cap,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20MintableBurnable.push(child);
    }
  }

  function getLatestChildrenErc20() external view returns (address) {
    if (childrenErc20.length > 0) {
      return address(childrenErc20[childrenErc20.length - 1]);
    }
    return address(childrenErc20[0]);
  }

  function getLatestChildrenErc20Mintable() external view returns (address) {
    if (childrenErc20Mintable.length > 0) {
      return address(childrenErc20Mintable[childrenErc20Mintable.length - 1]);
    }
    return address(childrenErc20Mintable[0]);
  }

  function getLatestChildrenErc20Burnable() external view returns (address) {
    if (childrenErc20Burnable.length > 0) {
      return address(childrenErc20Burnable[childrenErc20Burnable.length - 1]);
    }
    return address(childrenErc20Burnable[0]);
  }

  function getLatestChildrenErc20MintableBurnable()
    external
    view
    returns (address)
  {
    if (childrenErc20MintableBurnable.length > 0) {
      return
        address(
          childrenErc20MintableBurnable[
            childrenErc20MintableBurnable.length - 1
          ]
        );
    }
    return address(childrenErc20MintableBurnable[0]);
  }
}