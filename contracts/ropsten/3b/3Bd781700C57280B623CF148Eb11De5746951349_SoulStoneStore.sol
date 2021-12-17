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

    struct SoulStoneOnSale {
        uint256 amount;
        uint256 price;
    }

    mapping(uint8 => SoulStoneOnSale) public _ssObjects; // rarity => SoulStoneOnSale Object
    SoulStoneToken public ss;
    uint256 _blindBagPrice = 0.2 ether;
    uint256 _amountLimitPerTime = 10;

    constructor(SoulStoneToken _ss) {
        ss = _ss;
        _ssObjects[4] = SoulStoneOnSale({amount: 7000, price: 0.15 ether});
        _ssObjects[8] = SoulStoneOnSale({amount: 2000, price: 0.3 ether});
        _ssObjects[12] = SoulStoneOnSale({amount: 550, price: 1 ether});
        _ssObjects[16] = SoulStoneOnSale({amount: 250, price: 5 ether});
    }

    function buySoulStone(uint8 _rarity, uint256 _amount)
        public
        payable
        override
        onlyEOA
    {
        require(
            _amount <= _amountLimitPerTime,
            "Only can buy 10 SoulStones one time"
        );

        uint256 totalPrice = priceOf(_rarity) * _amount;
        require(msg.value >= totalPrice, "Insufficient balance");

        uint256 supply = supplyOf(_rarity);
        require((supply > 0 && supply >= _amount), "Insufficient SoulStones");

        payto(address(this), totalPrice);
        uint256[] memory tokenIds = _mintSoulStone(
            msg.sender,
            _rarity,
            _amount
        );

        emit Transfer(msg.sender, address(this), totalPrice);
        emit SoulStoneSold(msg.sender, tokenIds);
    }

    function _mintSoulStone(
        address _buyer,
        uint8 _rarity,
        uint256 _amount
    ) private onlyEOA returns (uint256[] memory) {

        uint256[] memory tokenIds = new uint256[](_amount);
        for (uint256 i = 0; i < _amount; i++) {
          tokenIds[i] = ss.mint(_buyer, _rarity);
        }

        SoulStoneOnSale storage ssOnSale = _ssObjects[_rarity];
        ssOnSale.amount = ssOnSale.amount - _amount;
        return tokenIds;
    }

    function openBlindBag() public payable override onlyEOA {
        require(msg.value >= _blindBagPrice, "Insufficient balance");

        uint8 _rarity = randomRarity();
        uint256 currentRaritySupply = supplyOf(_rarity);
        require(currentRaritySupply > 0, "Insufficient SoulStones");

        payto(address(this), _blindBagPrice);
        uint256[] memory tokenIds = _mintSoulStone(msg.sender, _rarity, 1);

        emit Transfer(msg.sender, address(this), _blindBagPrice);
        emit SoulStoneSold(msg.sender, tokenIds);
    }

    function buyGenesis(uint256 _nftId) public override onlyEOA {}

    function sellGenesis(uint256 _nftId, uint256 _price) public override {}

    function randomRarity() public view returns (uint8) {
        // Get left count
        uint256 leftSupply = 0;
        for (uint8 i = 4; i <= 16; i += 4) {
            SoulStoneOnSale memory ssOnSale = _ssObjects[i];
            leftSupply += ssOnSale.amount;
        }

        require(leftSupply > 0, "Soul stone sold out");

        // Get random index
        uint256 min = 0;
        uint256 max = leftSupply;
        uint256 randomIndex = Random.randomNumberBetween(min, max);

        // Hit target rarity
        uint8 rarity;
        uint256 index;
        for (uint8 i = 4; i <= 16; i += 4) {
            index += _ssObjects[i].amount;

            if (randomIndex <= index && index != 0) {
                rarity = i;
                break;
            }
        }
        return rarity;
    }

    function supplyOf(uint8 _rarity) public view override returns (uint256) {
        require(
            (_rarity == 4 || _rarity == 8 || _rarity == 12 || _rarity == 16),
            "This rarity have not been supported"
        );
        SoulStoneOnSale storage ssOnSale = _ssObjects[_rarity];
        return ssOnSale.amount;
    }

    function priceOf(uint8 _rarity) public view override returns (uint256) {
        require(
            (_rarity == 4 || _rarity == 8 || _rarity == 12 || _rarity == 16),
            "This rarity have not been supported"
        );
        SoulStoneOnSale storage ssOnSale = _ssObjects[_rarity];
        return ssOnSale.price;
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
            Library.isContract(_msgSender()) == false &&
                tx.origin == _msgSender(),
            "Function can only be called by EOA"
        );
        _;
    }
}

// (await SoulStoneStore.deployed()).buySoulStone(4, 5, {from: accounts[0], value: 0.15 * 5 * 1e18 })
// (await SoulStoneStore.deployed()).openBlindBag({from: accounts[0], value: 0.2 * 1e18 })
// (await SoulStoneStore.deployed()).address
// (await SoulStoneStore.deployed()).owner()
// (await SoulStoneStore.deployed()).address

// let random = (await SoulStoneStore.deployed()).randomRarity()
// random.toString()

// (await instance.supplyOf(4)).toString()
// (await instance.supplyOf(8)).toString()
// (await instance.supplyOf(12)).toString()
// (await instance.supplyOf(16)).toString()

// (await instance.getBalance()).toString()

// (await SoulStoneToken.deployed()).name()