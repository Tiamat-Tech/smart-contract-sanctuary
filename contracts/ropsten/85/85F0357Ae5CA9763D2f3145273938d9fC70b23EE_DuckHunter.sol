// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "./utils/IGameItems.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DuckHunter is Ownable {
    using SafeERC20 for IERC20;

    struct GameInfo {
        uint256 shotDuck;
        uint256 score;
        uint256[] itemIds;
        uint256[] amounts;
    }

    mapping(uint256 => mapping(address => uint256[])) gameLists;
    mapping(uint256 => GameInfo) public gameInfos;

    // mapping(uint256 => address[]) public players;

    uint256 public gameNumber;
    address public tokenAddress;
    address public gameItemsAddress;

    event AddGameInfo(
        uint256 indexed gameId,
        address player,
        uint256 shotDuck,
        uint256 score,
        uint256[] itemIds,
        uint256[] amounts
    );

    constructor(address _tokenAddress, address _gameItemsAddress) {
        tokenAddress = _tokenAddress;
        gameItemsAddress = _gameItemsAddress;
    }

    function getTokenInstance() internal view returns (IERC20) {
        return IERC20(tokenAddress);
    }

    function setTokenInstance(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    function getGameItemsInstance() internal view returns (IGameItems) {
        return IGameItems(gameItemsAddress);
    }

    function setGameItemsInstance(address _gameItemsAddress)
        external
        onlyOwner
    {
        gameItemsAddress = _gameItemsAddress;
    }

    function addGameInfo(
        uint256 _gameId,
        address _player,
        uint256 _shotDuck,
        uint256 _score,
        uint256[] calldata _itemIds,
        uint256[] calldata _amounts
    ) external onlyOwner {
        IGameItems gameItems = getGameItemsInstance();

        require(
            gameItems.isApprovedForAll(_player, address(this)),
            "DuckHunter.sol: Player doesn't set allowance to this game"
        );

        gameItems.burnBatch(_player, _itemIds, _amounts);

        uint256 gameNo = ++gameNumber;
        gameLists[_gameId][_player].push(gameNo);

        GameInfo storage gameInfo = gameInfos[gameNo];
        gameInfo.shotDuck = _shotDuck;
        gameInfo.score = _score;
        gameInfo.itemIds = _itemIds;
        gameInfo.amounts = _amounts;

        emit AddGameInfo(
            _gameId,
            _player,
            _shotDuck,
            _score,
            _itemIds,
            _amounts
        );

        // GameInfo memory gameInfo = GameInfo({
        //     shotDuck: _shotDuck,
        //     score: _score,
        //     items: _items
        // });
        // gameItems.burn(_player, )
    }

    function getGameNumber(uint256 _gameId, address _player)
        public
        view
        returns (uint256[] memory)
    {
        return gameLists[_gameId][_player];
    }

    // function getGameInfo(uint256 _gameId, address _player)
    //     public
    //     view
    //     returns (GameInfo[] memory)
    // {
    //     return gameInfos[_gameId][_player];
    // }

    // function numberOfGame(uint256 _gameId, address _player)
    //     public
    //     view
    //     returns (uint256)
    // {
    //     return gameInfos[_gameId][_player].length;
    // }
}