// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;
pragma abicoder v2;

import "./CryptoZooNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

interface IZoonERC20 is IERC20 {
    function win(address winner, uint256 reward) external;
}

contract Battle is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    enum BattleResult {
        LOSE,
        WIN
    }

    enum MonsterLevel {
        LEVEL_1, // 70-80%
        LEVEL_2, // 60-70%
        LEVEL_3, // 50-60%
        LEVEL_4 // 10-20%
    }

    event BattleEvent(
        uint256 indexed _tokenId,
        MonsterLevel monster,
        address user,
        BattleResult result
    );
    event Withdraw(address indexed user, uint256 indexed pid, uint256 _tokenId);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 _tokenId
    );

    // The CryptoZooNFT TOKEN!
    IZoonERC20 public zoonerToken;
    CryptoZooNFT public zoonerNFT;
    ManagerInterface public manager;

    mapping(uint256 => uint256[]) public battleSessions;

    constructor(
        address _manager,
        IZoonERC20 _zoonerToken,
        CryptoZooNFT _zoonerNFT
    ) {
        zoonerToken = _zoonerToken;
        zoonerNFT = _zoonerNFT;

        manager = ManagerInterface(_manager);
    }

    modifier validSessionBattle(uint256 _tokenId) {
        uint256[] storage sessions = battleSessions[_tokenId];
        uint256 level = zoonerNFT.getRare(_tokenId);
        uint256 limit = manager.timesBattle(level);
        uint256 times = battleTimes(_tokenId);
        if (times >= limit) {
            uint256 afterTime = sessions[times - limit].add(
                manager.timeLimitBattle()
            );
            console.log("times %s limit %s", times, limit);
            console.log(
                "afterTime %s timestamp %s ",
                afterTime,
                block.timestamp
            );
            require(afterTime < block.timestamp, "reach limit times battle");
        } else {
            console.log("timestamp: %s", block.timestamp);
        }
        _;
    }

    function battleTimes(uint256 _tokenId) public view returns (uint256) {
        return battleSessions[_tokenId].length;
    }

    function setManager(address _config) public onlyOwner {
        manager = ManagerInterface(_config);
    }

    function setNFT(address _zoonerNFT) public onlyOwner {
        zoonerNFT = CryptoZooNFT(_zoonerNFT);
    }

    function setERC20(address _zoonerERC20) public onlyOwner {
        zoonerToken = IZoonERC20(_zoonerERC20);
    }

    function battleReward(uint256 level, uint256 _winRate)
        private
        view
        returns (uint256)
    {
        // Battle Reward: Reward = x * level * (100-winrate) * Legendary Point
        uint256 x = manager.xBattle();
        console.log("x battle: %s", x);
        console.log("NFT level: %s", level);
        return x.mul(level).mul(uint256(100).sub(_winRate));
    }

    function getWinRate(MonsterLevel _monster) private view returns (uint256) {
        uint256 winRateRnd = random(uint256(_monster), 1);
        if (_monster == MonsterLevel.LEVEL_1) {
            return winRateRnd.add(70);
        } else if (_monster == MonsterLevel.LEVEL_2) {
            return winRateRnd.add(60);
        } else if (_monster == MonsterLevel.LEVEL_3) {
            return winRateRnd.add(50);
        } else if (_monster == MonsterLevel.LEVEL_4) {
            return winRateRnd.add(10);
        }
        return 100;
    }

    function battle(uint256 _tokenId, MonsterLevel _monster)
        external
        validSessionBattle(_tokenId)
        returns (BattleResult result)
    {
        require(zoonerNFT.ownerOf(_tokenId) == _msgSender(), "not own");

        result = BattleResult.LOSE;
        uint256 winRate = getWinRate(_monster);
        uint256 monsterLevel = uint256(_monster);
        console.log("monster level: %s", monsterLevel + 1);
        uint256 rnd = random(_tokenId, 4).div(100);

        console.log("winRate: %s rnd %s", winRate, rnd);

        uint256 monsterRate = monsterLevel < 4
            ? monsterLevel
            : monsterLevel + 1;

        uint256 level = zoonerNFT.zoonerLevel(_tokenId);
        // 1,2,3,5 * level * (100-winRate) * 10
        uint256 exp = monsterRate.mul(10).mul(level).mul(
            uint256(100).sub(winRate)
        );
        console.log("exp init: %s", exp);
        if (rnd < winRate) {
            result = BattleResult.WIN;
            uint256 reward = battleReward(level, winRate);
            zoonerToken.win(_msgSender(), reward);
            console.log("reward: %s", reward);
        } else {
            exp = exp.mul(manager.loseRate()).div(100);
        }
        console.log("exp: %s", exp);
        zoonerNFT.exp(_tokenId, exp);
        console.log("result: %s", uint256(result) == 0 ? "lose" : "win");

        battleSessions[_tokenId].push(block.timestamp);
        emit BattleEvent(_tokenId, _monster, _msgSender(), result);
    }

    function random(uint256 _id, uint256 _length)
        private
        view
        returns (uint256)
    {
        return
            uint256(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.difficulty,
                            block.timestamp,
                            _id,
                            _length
                        )
                    )
                )
            ) % (10**_length);
    }
}