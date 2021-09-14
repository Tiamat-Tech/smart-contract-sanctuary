// SPDX-License-Identifier: MIT

/*
  inspired by (w) (a) (g) (m) (i) by dom
*/
import "./Love.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

pragma solidity ^0.8.0;

contract MyRevengeCat is Ownable, ReentrancyGuard {
    address payable public devAddr;
    bool _birthed;
    uint256 public interactPrice = 0.05 ether;
    address public LoveToken;
    event CaretakerLoved(address indexed caretaker, uint256 indexed amount);
    
    uint256 lastFeedBlock;
    uint256 lastCleanBlock;
    uint256 lastPlayBlock;
    uint256 lastSleepBlock;
    
    uint256 internal hunger;
    uint256 internal uncleanliness;
    uint256 internal boredom;
    uint256 internal sleepiness;
    
    constructor(address _LoveToken) Ownable() {
        LoveToken = _LoveToken;
        devAddr = payable(msg.sender);
        lastFeedBlock = block.number;
        lastCleanBlock = block.number;
        lastPlayBlock = block.number;
        lastSleepBlock = block.number;
        
        hunger = 100;
        uncleanliness = 100;
        boredom = 100;
        sleepiness = 100;
    }
    
    function sendLove(address caretaker, uint256 amount) internal {
        Love(LoveToken).mint(caretaker, amount);
        emit CaretakerLoved(caretaker, amount);
    }
    
    function feed() public payable nonReentrant {
        require(getAlive(), "It appears they are no longer with us.");
        require(getHunger() <= 75, "I'm not hungry!");
        require(msg.value == interactPrice);

        devAddr.transfer(msg.value);
        lastFeedBlock = block.number;
        
        hunger = hunger + 25;
        boredom = boredom - 10;
        uncleanliness = uncleanliness - 3;

        sendLove(msg.sender, 1e18);
    }
    
    function clean() public payable nonReentrant {
        require(getAlive(), "It appears they are no longer with us.");
        require(getUncleanliness() <= 75, "I'm clean enough!");
        require(msg.value == interactPrice);

        devAddr.transfer(msg.value);

        lastCleanBlock = block.number;
        uncleanliness = uncleanliness - 25;
        
        sendLove(msg.sender, 1e18);
    }
    
    function play() public payable nonReentrant {
        require(getAlive(), "It appears they are no longer with us.");
        require(getBoredom() <= 75, "I'm not bored");
        require(msg.value == 0.05 ether);

        devAddr.transfer(msg.value);
        
        lastPlayBlock = block.number;
        
        boredom = boredom + 25;
        hunger = hunger - 10;
        sleepiness = sleepiness - 10;
        uncleanliness =  uncleanliness - 5;

        sendLove(msg.sender, 1e18);
    }
    
    function sleep() public payable nonReentrant {
        require(getAlive(), "It appears they are no longer with us.");
        require(getSleepiness() <= 75, "I'm not sleepy at all!");
        require(msg.value == interactPrice);

        devAddr.transfer(msg.value);
        
        lastSleepBlock = block.number;
        
        sleepiness = sleepiness + 25;
        uncleanliness = uncleanliness - 5;
        
        sendLove(msg.sender, 1e18);
    }

    function revive() public payable nonReentrant {
        require(!getAlive(), "I'm not dead, what are you doing?");
        require(msg.value == interactPrice);

        devAddr.transfer(msg.value);

        lastFeedBlock = block.number;
        lastCleanBlock = block.number;
        lastPlayBlock = block.number;
        lastSleepBlock = block.number;

        boredom = 100;
        hunger = 100;
        sleepiness = 100;
        uncleanliness = 100;
    } 

    function testState() public {
            boredom = 30;
            hunger = 50;
            sleepiness = 35;
            uncleanliness = 25;
        }
    
    function getStatus() public view returns (string memory) {
        uint256 mostNeeded = 0;
        
        string[4] memory goodStatus = [
            "Hello, I'm doing great today!!",
            "*Purrs Affectionately*",
            "You're the best!",
            "I love you!"
        ];

        
        string memory status = goodStatus[block.number % 4];
        
        uint256 _hunger = getHunger();
        uint256 _uncleanliness = getUncleanliness();
        uint256 _boredom = getBoredom();
        uint256 _sleepiness = getSleepiness();
        
        if (getAlive() == false) {
            return "The revenge cat appears to no longer be with us. Please revive them!";
        }
        
        if (_hunger < 50 && _hunger < mostNeeded) {
            mostNeeded = _hunger;
            status = "I could use a snack..";
        }
        
        if (_uncleanliness < 50 && _uncleanliness < mostNeeded) {
            mostNeeded = _uncleanliness;
            status = "I stink. Can you bathe me?";
        }
        
        if (_boredom < 50 && _boredom < mostNeeded) {
            mostNeeded = _boredom;
            status = "I'm so bored. Play with me!";
        }
        
        if (_sleepiness < 50 && _sleepiness < mostNeeded) {
            mostNeeded = _sleepiness;
            status = "I'm tired..Can you cuddle with me?";
        }
        
        return status;
    }
    
    function getAlive() public view returns (bool) {
        return getHunger() > 0 && getUncleanliness() > 0 &&
            getBoredom() > 0 && getSleepiness() > 0;
    }
    
    function getHunger() public view returns (uint256) {
        return hunger - ((block.number - lastFeedBlock) / 50);
    }
    
    function getUncleanliness() public view returns (uint256) {
        return uncleanliness - ((block.number - lastCleanBlock) / 50);
    }
    
    function getBoredom() public view returns (uint256) {
        return boredom - ((block.number - lastPlayBlock) / 50);
    }
    
    function getSleepiness() public view returns (uint256) {
        return sleepiness - ((block.number - lastSleepBlock) / 50);
    }

    function setOwner(address payable _devAddr) external onlyOwner {
        devAddr = _devAddr;
    }
}