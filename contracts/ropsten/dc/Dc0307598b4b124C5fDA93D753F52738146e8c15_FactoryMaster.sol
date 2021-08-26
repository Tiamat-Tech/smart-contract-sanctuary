//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../token/ERC20/ERC20.sol';
import '../token/ERC721/ERC721.sol';
import '../token/ERC2917/ERC2917.sol';

contract FactoryMaster {
  ERC20[] public childrenErc20;
  ERC721[] public childrenErc721;
  ERC2917[] public childrenErc2917;

  uint256 constant fee_erc20 = 0 ether;
  uint256 constant fee_erc721 = 0 ether;
  uint256 constant fee_erc2917 = 0 ether;

  event ChildCreatedERC20(address childAddress, string name, string symbol);
  event ChildCreatedERC721(address childAddress, string name, string symbol);
  event ChildCreated2917(
    address childAddress,
    string name,
    string symbol,
    uint256 _interestsRate
  );

  enum Types {
    none,
    erc20,
    erc721,
    erc2917
  }

  function createChild(
    Types types,
    string memory name,
    string memory symbol,
    uint256 _interestsRate
  ) external payable {
    require(types != Types.none, 'you must enter the word 1');
    require(
      keccak256(abi.encodePacked((name))) != keccak256(abi.encodePacked((''))),
      'requireed value'
    );
    require(
      keccak256(abi.encodePacked((symbol))) !=
        keccak256(abi.encodePacked((''))),
      'requireed value'
    );

    if (types == Types.erc20) {
      require(msg.value >= fee_erc20, 'ERC20:value must be greater than 0.2');

      ERC20 child = new ERC20(name, symbol);
      childrenErc20.push(child);
      emit ChildCreatedERC20(address(child), name, symbol);
    }
    if (types == Types.erc721) {
      require(msg.value >= fee_erc721, 'ERC721:value must be greater than 0.3');

      ERC721 child = new ERC721(name, symbol);
      childrenErc721.push(child);
      emit ChildCreatedERC721(address(child), name, symbol);
    }
    if (types == Types.erc2917) {
      require(_interestsRate >= 0, 'value must be greater than 0');
      require(
        msg.value >= fee_erc2917,
        'ERC2917:value must be greater than 0.4'
      );

      ERC2917 child = new ERC2917(name, symbol, _interestsRate);
      childrenErc2917.push(child);
      emit ChildCreated2917(address(child), name, symbol, _interestsRate);
    }
  }
}