// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./utils/IGameItems.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Marketplace is ERC1155Holder, Ownable {
    using SafeERC20 for IERC20;

    struct Item {
        string name;
        uint256 quantity;
        uint256 price;
        uint256 maxSupply;
        bool isClosed;
    }

    mapping(address => mapping(address => uint256[])) itemsInGame;
    mapping(address => mapping(uint256 => Item)) public items;

    address public tokenAddress;

    event AddItem(
        address indexed gameItemsAddress,
        address gameAddress,
        uint256 indexed itemId,
        uint256 quantity,
        uint256 price,
        uint256 initialSupply,
        uint256 maxSupply
    );

    event RemoveItem(
        address indexed gameItemsAddress,
        address gameAddress,
        uint256 indexed itemId
    );

    event SetMaxSupply(
        address indexed gameItemsAddress,
        uint256 indexed itemId,
        uint256 maxSupply
    );

    event SetOpenCloseSelling(
        address indexed gameItemsAddress,
        uint256 indexed itemId,
        bool isClosed
    );

    event PurchaseItem(
        address indexed gameItemsAddress,
        uint256 indexed itemId,
        address player,
        uint256 volume
    );

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function getTokenInstance() internal view returns (IERC20) {
        return IERC20(tokenAddress);
    }

    function setTokenInstance(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    function getGameItemsInstance(address _gameItemsAddress)
        internal
        pure
        returns (IGameItems)
    {
        return IGameItems(_gameItemsAddress);
    }

    function getGameItemsList(address _gameItemsAddress, address _gameAddress)
        public
        view
        returns (uint256[] memory)
    {
        return itemsInGame[_gameItemsAddress][_gameAddress];
    }

    function addItem(
        address _gameItemsAddress,
        address _gameAddress,
        string memory _name,
        uint256 _quantity,
        uint256 _price,
        uint256 _initialSupply,
        uint256 _maxSupply,
        bytes memory _data
    ) external onlyOwner {
        IGameItems gameItems = getGameItemsInstance(_gameItemsAddress);
        uint256 itemId = gameItems.create(_initialSupply, _data);
        itemsInGame[_gameItemsAddress][_gameAddress].push(itemId);

        Item storage item = items[_gameItemsAddress][itemId];
        item.name = _name;
        item.quantity = _quantity;
        item.price = _price;
        item.maxSupply = _maxSupply;

        emit AddItem(
            _gameItemsAddress,
            _gameAddress,
            itemId,
            _quantity,
            _price,
            _initialSupply,
            _maxSupply
        );
    }

    function removeItem(
        address _gameItemsAddress,
        address _gameAddress,
        uint256 _itemId,
        uint256 _index
    ) external onlyOwner {
        delete items[_gameItemsAddress][_itemId];

        uint256[] storage allItems = itemsInGame[_gameItemsAddress][
            _gameAddress
        ];
        allItems[_index] = allItems[allItems.length - 1];
        allItems.pop();

        emit RemoveItem(_gameItemsAddress, _gameAddress, _itemId);
    }

    function setMaxSupply(
        address _gameItemsAddress,
        uint256 _itemId,
        uint256 _maxSupply
    ) external onlyOwner {
        IGameItems gameItems = getGameItemsInstance(_gameItemsAddress);
        uint256 totalSupply = gameItems.checkTotalSupply(_itemId);

        require(
            _maxSupply >= totalSupply,
            "Marketplace.sol: Max supply can't be less than total supply"
        );

        items[_gameItemsAddress][_itemId].maxSupply = _maxSupply;

        emit SetMaxSupply(_gameItemsAddress, _itemId, _maxSupply);
    }

    function setOpenCloseSelling(
        address _gameItemsAddress,
        uint256 _itemId,
        bool _isClosed
    ) external onlyOwner {
        items[_gameItemsAddress][_itemId].isClosed = _isClosed;

        emit SetOpenCloseSelling(_gameItemsAddress, _itemId, _isClosed);
    }

    function purchaseItem(
        address _gameItemsAddress,
        uint256 _itemId,
        uint256 _volume,
        bytes memory _data
    ) external {
        IGameItems gameItems = getGameItemsInstance(_gameItemsAddress);
        uint256 totalSupply = gameItems.checkTotalSupply(_itemId);

        Item memory item = items[_gameItemsAddress][_itemId];
        uint256 cost = item.price * _volume;
        uint256 quantity = item.quantity * _volume;

        IERC20 token = getTokenInstance();

        require(
            token.balanceOf(msg.sender) >= cost,
            "Marketplace.sol: Insufficient balance."
        );

        require(
            token.allowance(msg.sender, address(this)) >= cost,
            "Marketplace.sol: Insufficient allowance to user's token, please approve token allowance."
        );

        require(
            item.maxSupply >= (totalSupply + quantity),
            "Marketplace.sol: Not enough supply"
        );

        require(
            !item.isClosed,
            "Marketplace.sol: Item is not available for purchase"
        );

        token.safeTransferFrom(msg.sender, address(this), cost);
        gameItems.mint(msg.sender, _itemId, quantity, _data);

        emit PurchaseItem(_gameItemsAddress, _itemId, msg.sender, _volume);
    }
}