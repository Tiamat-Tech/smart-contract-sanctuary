pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Avalia is ERC1155 {
  uint256 public constant AVA_COIN = 0;
  uint256 public constant PROJECT_BADGE_BASE = 1001;

  constructor() ERC1155("https://avalia.io/nft/{id}.json") {
    uint supply = 1000000;
    console.log("Deploying Avalia smart contract with initial supply: ", supply);
    _mint(msg.sender, AVA_COIN, supply, "");
  }

}