// contracts/SoulStoneStore.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISoulStoneStore.sol";
import "./SoulStoneToken.sol";
import "./GenesisToken.sol";
import "./libraries/Library.sol";
import "./libraries/Random.sol";

contract SoulStoneStore is ISoulStoneStore, Ownable {
    using SafeMath for uint256;

    mapping(uint8 => uint256) public ssOnsale; // rarity => Left count
    SoulStoneToken ss = new SoulStoneToken();

    uint256[] _soulStonePrices = [0.15 ether, 0.3 ether, 1 ether, 5 ether];
    uint256 _blindBagPrice = 0.2 ether;

    constructor() {
        ssOnsale[0] = 7000;
        ssOnsale[1] = 2000;
        ssOnsale[2] = 550;
        ssOnsale[3] = 250;
    }

    function buySoulStone(uint8 _rarity) public payable override onlyEOA {
      
        uint256 price = priceOf(_rarity);
        require(msg.value >= price, "Insufficient balance");

        uint256 currentRaritySupply = totalSupplyOf(_rarity);
        require(currentRaritySupply > 0, "Soul stone sold out");

        payto(address(this), price);
        ssOnsale[_rarity] -= 1;
        uint256 tokenId = ss.mint(msg.sender, _rarity);

        emit Transfer(msg.sender, address(this), price);
        emit SoulStoneSold(msg.sender, tokenId);
    }

    function openBlindBag() public payable override onlyEOA {
        require(msg.value >= _blindBagPrice, "Insufficient balance");

        uint8 _rarity = randomRarity();
        uint256 currentRaritySupply = totalSupplyOf(_rarity);
        require(currentRaritySupply > 0, "Soul stone sold out");

        payto(address(this), _blindBagPrice);
        ssOnsale[_rarity] -= 1;
        uint256 tokenId = ss.mint(msg.sender, _rarity);

        emit Transfer(msg.sender, address(this), _blindBagPrice);
        emit SoulStoneSold(msg.sender, tokenId);
    }

    function buyGenesis(uint256 _nftId) public override onlyEOA {}

    function sellGenesis(uint256 _nftId, uint256 _price) public override {}

    function randomRarity() public view returns (uint8) {

      // Get left count
      uint256 ssLeftCount = 0;
      for(uint8 i = 0; i < 4; i++){
        ssLeftCount += ssOnsale[i];
      }

      require(ssLeftCount > 0, "Soul stone sold out");
      
      // Get random index
      uint256 min = 0;
      uint256 max = ssLeftCount;
      uint256 randomIndex = Random.randomNumberBetween(min, max);

      // Hit target rarity
      uint8 rarity;
      uint256 index;
      for(uint8 i = 0; i < 4; i++){
        index += ssOnsale[i];
        if (randomIndex <= index && index != 0) {
          rarity = i;
          break;
        }
      }
      return rarity;
    }

    function totalSupplyOf(uint8 _rarity)
        public
        view
        override
        returns (uint256)
    {
        require(_rarity < 4, "Index out of range");
        return ssOnsale[_rarity];
    }

    function priceOf(uint8 _rarity) public view override returns (uint256) {
        require(_rarity < 4, "Index out of range");
        return _soulStonePrices[_rarity];
    }

    function getBalance() public view override returns (uint256) {
        return address(this).balance;
    }

    function pay() public payable {}

    function withdraw() public override onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function payto(address to, uint256 value) private {
        payable(to).transfer(value);
    }

    modifier onlyEOA() {
        require(
            Library.isContract(_msgSender()) == false && tx.origin == _msgSender(),
            "Function can only be called by EOA"
        );
        _;
    }
}