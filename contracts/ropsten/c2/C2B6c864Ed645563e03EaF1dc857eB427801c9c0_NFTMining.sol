pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

//FOR TESTING PURPOSES
import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import 'hardhat/console.sol';

contract NFTMining is ERC1155Holder, Ownable {
    IERC1155 public erc1155;
    IERC20 public erc20;

    uint256 public constant PERIOD = 1 days;
    uint256 public constant ONE_TOKEN_IN_WEI = 1e18;
    bytes public constant DEF_DATA = '';

    uint256 public avaliableIdsCounter = 0;
    uint256 public minersCounter = 0;

    struct User {
        uint256 minersCounter;
        uint256[] minersIds;
    }

    struct Miner {
        uint256 amount;
        uint256 start;
        uint256 rate;
        uint256 lastHarvest;
        address owner;
    }

    mapping(address => User) public users;
    mapping(uint256 => Miner) public pool;
    mapping(uint256 => uint256) public rates;

    event MinerCreation(
        address indexed user,
        uint256 indexed tokenId,
        uint256 amount
    );

    event Harvest(
        address indexed user,
        uint256 indexed minerId,
        uint256 amount
    );

    constructor(address TOKEN1155, address TOKEN20) {
        erc1155 = IERC1155(TOKEN1155);
        erc20 = IERC20(TOKEN20);

        transferOwnership(msg.sender);
    }

    function mineAnItem(uint256 tokenId, uint256 amount) external {
        require(
            erc1155.balanceOf(msg.sender, tokenId) >= amount,
            "You don't have enough tokens"
        );
        require(amount > 0, 'Amount must be greater than zero');
        require(rates[tokenId] != 0, "This item can't be mined");

        erc1155.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            DEF_DATA
        );

        _createMiner(tokenId, amount, msg.sender);

        users[msg.sender].minersCounter += 1;
        users[msg.sender].minersIds.push(minersCounter);

        emit MinerCreation(msg.sender, tokenId, amount);
    }

    function harvest(uint256 minerId) external {
        require(pool[minerId].start != 0, "This miner doesn't exists");
        require(
            pool[minerId].start != 0,
            "You don't have a miner with this id"
        );
        require(
            block.timestamp - pool[minerId].start < 30 days,
            'Your mining is expired!'
        );

        uint256 reward = (block.timestamp - pool[minerId].lastHarvest) *
            pool[minerId].rate;
        erc20.transfer(msg.sender, reward);
        
        pool[minerId].lastHarvest = block.timestamp;

        emit Harvest(msg.sender, minerId, reward);
    }

    function setRate(uint256 tokenId, uint256 rate) public onlyOwner {
        _setRate(tokenId, rate);
    }

    function _createMiner(
        uint256 tokenId,
        uint256 amount,
        address user
    ) internal {
        minersCounter += 1;

        pool[minersCounter] = Miner({
            amount: amount,
            start: block.timestamp,
            rate: rates[tokenId],
            lastHarvest: block.timestamp,
            owner: user
        });
    }

    function _setRate(uint256 tokenId, uint256 rate) internal {
        rates[tokenId] = rate;
        avaliableIdsCounter += 1;
    }

        function getAllUserMiners(address user)
        public
        view
        returns (
            uint256[] memory amounts,
            uint256[] memory startPoints,
            uint256[] memory rates,
            uint256[] memory harvestedLastTime
        )
    {
        uint256 amountOfMiners = users[msg.sender].minersCounter;

        uint256[] memory amounts = new uint256[](minersCounter);
        uint256[] memory startPoints = new uint256[](minersCounter);
        uint256[] memory rates = new uint256[](minersCounter);
        uint256[] memory harvestedLastTime = new uint256[](minersCounter);

        for (uint256 miner = 0; miner < minersCounter; miner++) {
            amounts[miner] = pool[users[msg.sender].minersIds[miner]].amount;
            startPoints[miner] = pool[users[msg.sender].minersIds[miner]].start;
            rates[miner] = pool[users[msg.sender].minersIds[miner]].rate;
            harvestedLastTime[miner] = pool[users[msg.sender].minersIds[miner]].lastHarvest;

            return (amounts, startPoints, rates, harvestedLastTime);
        }
    }
}