//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../token/ERC20/ERC20Burnable.sol';
import '../token/ERC20/ERC20Mintable.sol';
import '../token/ERC20/ERC20MintableBurnable.sol';
import '../token/ERC20/ERC20FixedSupply.sol';
import '../libraries/Ownable.sol';

contract FactoryMaster is Ownable {
  ERC20FixedSupply[] private childrenErc20;
  ERC20Burn[] private childrenErc20Burn;

  ERC20Mintable[] private childrenErc20Mint;
  ERC20MintableBurnable[] private childrenErc20MintBurn;

  address private tokenOwner;
  uint256 constant fee_erc20 = 0.00001 ether;

  constructor(address _tokenOwner) {
    tokenOwner = _tokenOwner;
  }

  event ChildCreatedERC20(
    address childAddress,
    string name,
    string symbol,
    uint8 decimal,
    uint256 initialSuplly
  );

  event ChildCreatedERC20Burnable(
    address childAddress,
    string name,
    string symbol,
    uint8 decimal,
    uint256 initialSuplly
  );
  event ChildCreatedERC20Mintable(
    address childAddress,
    uint256 cap_,
    string name,
    string symbol,
    uint8 decimal,
    uint256 initialSupply
  );
  event ChildCreatedERC20MintableBurnable(
    address childAddress,
    uint256 cap_,
    string name,
    string symbol,
    uint8 decimal,
    uint256 initialSupply
  );

  enum Types {
    none,
    erc20,
    erc20Burn,
    erc20Mintable,
    erc20MintableBurnable
  }

  function createChild(
    Types types,
    uint256 cap_,
    string memory name,
    uint8 decimal,
    string memory symbol,
    uint256 initialSupply
  ) external payable {
    require(types != Types.none, 'you must enter the word 1');
    require(
      keccak256(abi.encodePacked((name))) != keccak256(abi.encodePacked(('')))
    );
    require(
      keccak256(abi.encodePacked((symbol))) != keccak256(abi.encodePacked(('')))
    );

    if (types == Types.erc20) {
      require(msg.value >= fee_erc20, 'ERC20:value must be greater than 0.2');

      ERC20FixedSupply child = new ERC20FixedSupply(
        tokenOwner,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20.push(child);
      emit ChildCreatedERC20(
        address(child),
        name,
        symbol,
        decimal,
        initialSupply
      );
    }
    if (types == Types.erc20Burn) {
      require(msg.value >= fee_erc20, 'ERC20:value must be greater than 0.2');

      ERC20Burn child = new ERC20Burn(
        tokenOwner,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20Burn.push(child);
      emit ChildCreatedERC20Burnable(
        address(child),
        name,
        symbol,
        decimal,
        initialSupply
      );
    }

    if (types == Types.erc20Mintable) {
      require(msg.value >= fee_erc20, 'ERC20:value must be greater than 0.2');

      ERC20Mintable child = new ERC20Mintable(
        tokenOwner,
        cap_,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20Mint.push(child);
      emit ChildCreatedERC20Mintable(
        address(child),
        cap_,
        name,
        symbol,
        decimal,
        initialSupply
      );
    }

    if (types == Types.erc20MintableBurnable) {
      require(msg.value >= fee_erc20, 'ERC20:value must be greater than 0.2');

      ERC20MintableBurnable child = new ERC20MintableBurnable(
        tokenOwner,
        cap_,
        name,
        symbol,
        decimal,
        initialSupply
      );
      childrenErc20MintBurn.push(child);
      emit ChildCreatedERC20MintableBurnable(
        address(child),
        cap_,
        name,
        symbol,
        decimal,
        initialSupply
      );
    }
  }

  // function createERC20Burnable(
  //   string memory name,
  //   string memory symbol,
  //   uint8 decimal,
  //   uint256 initialSupply
  // ) external {
  //   ERC20Burn child = new ERC20Burn(
  //     tokenOwner,
  //     name,
  //     symbol,
  //     decimal,
  //     initialSupply
  //   );
  //   child.init(name, symbol, decimal, initialSupply);
  //   // child.name()
  //   childrenErc20Burn.push(child);
  // }

  function getLatestChildrenErc20() external view returns (address) {
    if (childrenErc20.length > 0) {
      return address(childrenErc20[childrenErc20.length - 1]);
    }
    return address(childrenErc20[0]);
  }

  function getLatestChildrenErc20Burnable() external view returns (address) {
    if (childrenErc20Burn.length > 0) {
      return address(childrenErc20Burn[childrenErc20Burn.length - 1]);
    }
    return address(childrenErc20Burn[0]);
  }

  function getLatestChildrenErc20Mintable() external view returns (address) {
    if (childrenErc20Mint.length > 0) {
      return address(childrenErc20Mint[childrenErc20Mint.length - 1]);
    }
    return address(childrenErc20Mint[0]);
  }

  function getLatestChildrenErc20MintableBurnable()
    external
    view
    returns (address)
  {
    if (childrenErc20MintBurn.length > 0) {
      return address(childrenErc20MintBurn[childrenErc20MintBurn.length - 1]);
    }
    return address(childrenErc20MintBurn[0]);
  }
}