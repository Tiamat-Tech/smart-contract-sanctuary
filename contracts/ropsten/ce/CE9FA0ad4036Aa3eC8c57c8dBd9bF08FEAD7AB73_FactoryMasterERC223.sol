//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC223/ERC223Burnable.sol";
import "../token/ERC223/ERC223Mintable.sol";
import "../token/ERC223/ERC223.sol";
import "../libraries/config-fee.sol";
import "../token/ERC223/ERC223MintableBurnable.sol";

contract FactoryMasterERC223 {
  ERC223Token[] private childrenErc223Token;
  ERC223Mintable[] private childrenErc223Mintable;
  ERC223Burnable[] private childrenErc223Burnable;
  ERC223MintableBurnable[] private childrenErc223MintableBurnable;

  enum Types {
    none,
    erc223,
    erc223Mintable,
    erc223Burnable,
    erc223MintableBurnable
  }

  function createERC223Types(
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
    if (types == Types.erc223) {
      require(
        msg.value >= Config.fee_223,
        "ERC223:value must be greater than 0.0001"
      );
      ERC223Token child = new ERC223Token(name, symbol, decimal, initialSupply);
      childrenErc223Token.push(child);
    }
    if (types == Types.erc223Mintable) {
      require(
        msg.value >= Config.fee_223,
        "ERC223:value must be greater than 0.0001"
      );
      ERC223Mintable child = new ERC223Mintable(
        name,
        symbol,
        decimal,
        initialSupply,
        cap
      );
      childrenErc223Mintable.push(child);
    }

    if (types == Types.erc223Burnable) {
      require(
        msg.value >= Config.fee_223,
        "ERC223:value must be greater than 0.0001"
      );
      ERC223Burnable child = new ERC223Burnable(
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc223Burnable.push(child);
    }

    if (types == Types.erc223MintableBurnable) {
      require(
        msg.value >= Config.fee_223,
        "ERC223:value must be greater than 0.0001"
      );
      ERC223MintableBurnable child = new ERC223MintableBurnable(
        name,
        symbol,
        decimal,
        initialSupply,
        cap
      );
      childrenErc223MintableBurnable.push(child);
    }
  }

  function getLatestChildrenErc223() external view returns (address) {
    if (childrenErc223Token.length > 0) {
      return address(childrenErc223Token[childrenErc223Token.length - 1]);
    }
    return address(childrenErc223Token[0]);
  }

  function getLatestChildrenErc223Mintable() external view returns (address) {
    if (childrenErc223Mintable.length > 0) {
      return address(childrenErc223Mintable[childrenErc223Mintable.length - 1]);
    }
    return address(childrenErc223Mintable[0]);
  }

  function getLatestChildrenErc223Burnable() external view returns (address) {
    if (childrenErc223Burnable.length > 0) {
      return address(childrenErc223Burnable[childrenErc223Burnable.length - 1]);
    }
    return address(childrenErc223Burnable[0]);
  }

   function getLatestChildrenErc223MintableBurnable() external view returns (address) {
    if (childrenErc223MintableBurnable.length > 0) {
      return address(childrenErc223MintableBurnable[childrenErc223MintableBurnable.length - 1]);
    }
    return address(childrenErc223Burnable[0]);
  }
}