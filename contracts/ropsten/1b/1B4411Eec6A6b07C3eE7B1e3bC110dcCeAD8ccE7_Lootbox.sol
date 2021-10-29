//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Lootbox is ERC721, Ownable {
    IERC20 public kmon;
    mapping(uint256 => uint256) public lootboxPrices;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    event LootboxPurchased(uint256 _boxType, address indexed _buyer, address _to, uint256 _price);

    modifier onlyLootbox(uint256 _boxType) {
        require(
            _boxType == 0 || _boxType == 1 || _boxType == 2,
            'Lootbox type must be either basic, medium or premium'
        );
        _;
    }

    constructor(address _kmon) ERC721('Lootbox', 'LOOTBOX') {
        kmon = IERC20(_kmon);
    }

    function buyLootbox(address _to, uint256 _boxType) external onlyLootbox(_boxType) {
        uint256 boxPrice = lootboxPrices[_boxType];

        require(boxPrice > 0, 'Lootbox price must be set');

        kmon.transferFrom(_msgSender(), address(this), boxPrice);

        _tokenIds.increment();
        _safeMint(_msgSender(), _tokenIds.current());

        emit LootboxPurchased(_boxType, _msgSender(), _to, boxPrice);
    }

    function buyLootboxWithoutMinting(address _to, uint256 _boxType) external onlyLootbox(_boxType) {
        uint256 boxPrice = lootboxPrices[_boxType];

        require(boxPrice > 0, 'Lootbox price must be set');

        kmon.transferFrom(_msgSender(), address(this), boxPrice);

        emit LootboxPurchased(_boxType, _msgSender(), _to, boxPrice);
    }

    function setLootboxPrice(uint256 _boxType, uint256 _boxPrice) external onlyOwner onlyLootbox(_boxType) {
        lootboxPrices[_boxType] = _boxPrice;
    }

    function _baseURI() internal pure override returns (string memory) {
        return 'https://API.kryptomon.co/lootbox/';
    }

    function withdraw() public onlyOwner {
        kmon.transfer(owner(), kmon.balanceOf(address(this)));
    }
}