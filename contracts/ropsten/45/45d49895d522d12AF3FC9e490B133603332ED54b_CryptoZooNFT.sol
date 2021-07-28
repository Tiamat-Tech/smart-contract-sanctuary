// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./ERC721.sol";

contract CryptoZooNFT is ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    enum Tribe {
        SKYLER,
        HYDREIN,
        PLASMER,
        STONIC
    }

    event LayEgg(uint256 indexed tokenId, address buyer);
    event Evolve(uint256 indexed tokenId, uint256 dna);
    event Buy(
        uint256 indexed tokenId,
        address buyer,
        address seller,
        uint256 price
    );
    event UpdateTribe(uint256 indexed tokenId, Tribe tribe);
    event Exp(uint256 indexed tokenId, uint256 exp);
    event Working(uint256 indexed tokenId, uint256 time);
    event PlaceOrder(uint256 indexed tokenId, address seller, uint256 price);
    event CancelOrder(uint256 indexed tokenId, address seller);
    event FillOrder(uint256 indexed tokenId, address seller);

    struct CryptoZoon {
        uint256 generation;
        Tribe tribe;
        uint256 exp;
        uint256 dna;
        uint256 farmTime;
        uint256 bornTime;
    }

    struct ItemSale {
        uint256 tokenId;
        address owner;
        uint256 price;
    }

    uint256 public latestTokenId;
    mapping(uint256 => bool) public isEvolved;

    mapping(uint256 => CryptoZoon) internal zooners;
    mapping(uint256 => ItemSale) internal markets;

    EnumerableSet.UintSet private tokenSales;
    mapping(address => EnumerableSet.UintSet) private sellerTokens;

    IERC20 public zoonerERC20;

    constructor(
        string memory _name,
        string memory _symbol,
        address _manager,
        address _zoonerERC20
    ) ERC721(_name, _symbol, _manager) {
        zoonerERC20 = IERC20(_zoonerERC20);
    }

    modifier onlyFarmer() {
        require(manager.farmOwners(msg.sender), "require Farmer.");
        _;
    }

    modifier onlySpawner() {
        require(manager.evolvers(msg.sender), "require Spawner.");
        _;
    }

    modifier onlyBattlefield() {
        require(manager.battlefields(msg.sender), "require Battlefield.");
        _;
    }

    function priceEgg() public view returns (uint256) {
        return manager.priceEgg();
    }

    function feeEvolve() public view returns (uint256) {
        return manager.feeEvolve();
    }

    function _mint(address to, uint256 tokenId) internal override(ERC721) {
        super._mint(to, tokenId);

        _incrementTokenId();
    }

    function working(uint256 _tokenId, uint256 _time) public onlyFarmer {
        require(_time > 0, "no time");
        CryptoZoon storage zooner = zooners[_tokenId];
        zooner.farmTime = zooner.farmTime.add(_time);

        emit Working(_tokenId, _time);
    }

    function exp(uint256 _tokenId, uint256 _exp) public onlyBattlefield {
        require(_exp > 0, "no exp");
        CryptoZoon storage zooner = zooners[_tokenId];
        zooner.exp = zooner.exp.add(_exp);
        emit Exp(_tokenId, _exp);
    }

    function evolve(
        uint256 _tokenId,
        address _owner,
        uint256 _dna
    ) public onlySpawner {
        require(ownerOf(_tokenId) == _owner, "not own");
        CryptoZoon storage zooner = zooners[_tokenId];
        require(!isEvolved[_tokenId], "require: not evolved");

        zooner.bornTime = block.timestamp;
        zooner.dna = _dna;

        emit Evolve(_tokenId, _dna);
    }

    function changeTribe(
        uint256 _tokenId,
        address _owner,
        Tribe tribe
    ) external onlySpawner {
        require(ownerOf(_tokenId) == _owner, "not own");
        zoonerERC20.transferFrom(
            _msgSender(),
            manager.feeAddress(),
            manager.feeChangeTribe()
        );

        CryptoZoon storage zooner = zooners[_tokenId];
        zooner.tribe = tribe;

        emit UpdateTribe(_tokenId, tribe);
    }

    function layEgg(
        uint256 amount,
        address receiver,
        Tribe tribe
    ) external onlySpawner {
        require(amount > 0, "require: >0");
        if (amount == 1) _layEgg(receiver, tribe);
        else
            for (uint256 index = 0; index < amount; index++) {
                _layEgg(receiver, tribe);
            }
    }

    function _layEgg(address receiver, Tribe tribe) internal {
        uint256 nextTokenId = _getNextTokenId();
        _mint(receiver, nextTokenId);

        zooners[nextTokenId] = CryptoZoon({
            generation: manager.generation(),
            tribe: tribe,
            exp: 0,
            dna: 0,
            farmTime: 0,
            bornTime: block.timestamp
        });

        emit LayEgg(nextTokenId, receiver);
    }

    /**
     * @dev calculates the next token ID based on value of latestTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return latestTokenId.add(1);
    }

    /**
     * @dev increments the value of latestTokenId
     */
    function _incrementTokenId() private {
        latestTokenId++;
    }

    function getZooner(uint256 _tokenId)
        public
        view
        returns (CryptoZoon memory)
    {
        return zooners[_tokenId];
    }

    function zoonerLevel(uint256 _tokenId) public view returns (uint256) {
        return getLevel(getZooner(_tokenId).exp);
    }

    function getRare(uint256 _tokenId) public view returns (uint256) {
        uint256 dna = getZooner(_tokenId).dna;
        if (dna == 0) return 0;
        uint256 rareParser = dna / 10**26;
        if (rareParser < 5225) {
            return 1;
        } else if (rareParser < 7837) {
            return 2;
        } else if (rareParser < 8707) {
            return 3;
        } else if (rareParser < 9360) {
            return 4;
        } else if (rareParser < 9708) {
            return 5;
        } else {
            return 6;
        }
    }

    function getLevel(uint256 _exp) internal pure returns (uint256) {
        if (_exp < 100) {
            return 1;
        } else if (_exp < 350) {
            return 2;
        } else if (_exp < 1000) {
            return 3;
        } else if (_exp < 2000) {
            return 4;
        } else if (_exp < 4000) {
            return 5;
        } else {
            return 6;
        }
    }

    function placeOrder(uint256 _tokenId, uint256 _price) public {
        require(ownerOf(_tokenId) == _msgSender(), "not own");
        require(_price > 0, "nothing is free");

        tokenOrder(_tokenId, true, _price);

        emit PlaceOrder(_tokenId, _msgSender(), _price);
    }

    function cancelOrder(uint256 _tokenId) public {
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_tokenId];
        require(itemSale.owner == _msgSender(), "not own");

        tokenOrder(_tokenId, false, 0);

        emit CancelOrder(_tokenId, _msgSender());
    }

    function fillOrder(uint256 _tokenId) public {
        require(tokenSales.contains(_tokenId), "not sale");
        ItemSale storage itemSale = markets[_tokenId];
        uint256 feeMarket = itemSale.price.mul(manager.feeMarketRate()).div(
            manager.divPercent()
        );
        zoonerERC20.transferFrom(_msgSender(), manager.feeAddress(), feeMarket);
        zoonerERC20.transferFrom(
            _msgSender(),
            itemSale.owner,
            itemSale.price.sub(feeMarket)
        );

        tokenOrder(_tokenId, false, 0);
        emit FillOrder(_tokenId, _msgSender());
    }

    function tokenOrder(
        uint256 _tokenId,
        bool _sell,
        uint256 _price
    ) internal {
        ItemSale storage itemSale = markets[_tokenId];
        if (_sell) {
            transferFrom(_msgSender(), address(this), _tokenId);
            tokenSales.add(_tokenId);
            sellerTokens[_msgSender()].add(_tokenId);

            markets[_tokenId] = ItemSale({
                tokenId: _tokenId,
                price: _price,
                owner: _msgSender()
            });
        } else {
            transferFrom(address(this), _msgSender(), _tokenId);

            tokenSales.remove(_tokenId);
            sellerTokens[itemSale.owner].remove(_tokenId);
            markets[_tokenId] = ItemSale({
                tokenId: 0,
                price: 0,
                owner: address(0)
            });
        }
    }

    function marketsSize() public view returns (uint256) {
        return tokenSales.length();
    }

    function orders(address _seller) public view returns (uint256) {
        return sellerTokens[_seller].length();
    }

    function tokenSaleByIndex(uint256 index) public view returns (uint256) {
        return tokenSales.at(index);
    }

    function tokenSaleOfOwnerByIndex(address _seller, uint256 index)
        public
        view
        returns (uint256)
    {
        return sellerTokens[_seller].at(index);
    }

    function getSale(uint256 _tokenId) public view returns (ItemSale memory) {
        if (tokenSales.contains(_tokenId)) return markets[_tokenId];
        return ItemSale({tokenId: 0, owner: address(0), price: 0});
    }
}