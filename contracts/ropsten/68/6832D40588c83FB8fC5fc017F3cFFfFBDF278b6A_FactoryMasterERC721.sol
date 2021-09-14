//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../token/ERC721/ERC721Burnable-NFT.sol";
import "../token/ERC721/ERC721Mintable.sol";
import "../libraries/config-fee.sol";

contract FactoryMasterERC721 {
  ERC721Mintable[] public childrenErc721Mint;
  ERC721Burnable_NFT[] public childrenErc721Burn;

  event ChildCreatedERC721Mint(
    address childAddress,
    string name,
    string symbol
  );
  event ChildCreatedERC721Burn(
    address childAddress,
    string name,
    string symbol
  );

  enum Types {
    erc721mint,
    erc721burn
  }

  function createChildERC721(
    Types types,
    string memory name,
    string memory symbol
  ) external payable {
    require(
      keccak256(abi.encodePacked((name))) != keccak256(abi.encodePacked((""))),
      "requireed value"
    );
    require(
      keccak256(abi.encodePacked((symbol))) !=
        keccak256(abi.encodePacked((""))),
      "requireed value"
    );

    if (types == Types.erc721mint) {
      require(
        msg.value >= Config.fee_721_mint,
        "ERC721:value must be greater than 0.3"
      );

      ERC721Mintable child = new ERC721Mintable(name, symbol);
      childrenErc721Mint.push(child);
      emit ChildCreatedERC721Mint(address(child), name, symbol);
    }
    if (types == Types.erc721burn) {
      require(
        msg.value >= Config.fee_721_burn,
        "ERC721:value must be greater than 0.3"
      );

      ERC721Burnable_NFT child = new ERC721Burnable_NFT(name, symbol);
      childrenErc721Burn.push(child);
      emit ChildCreatedERC721Burn(address(child), name, symbol);
    }
  }
}