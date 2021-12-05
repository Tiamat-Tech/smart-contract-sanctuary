pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./NFT.sol";

contract MintAsset  {
  NFT[] public  erc1155;
  address public immutable owner;

  constructor()  {
   erc1155.push(new NFT("https://game.example/api/item/{id}.json"));
   erc1155.push(new NFT("https://game.example/api/item/{id}.json"));
   owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner can do this action");
    _;
  }

  function getNFT(uint256 id)  public view returns (NFT)  {
    return erc1155[id];
  }


}