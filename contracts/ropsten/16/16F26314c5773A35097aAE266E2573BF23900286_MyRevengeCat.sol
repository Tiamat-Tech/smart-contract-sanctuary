// SPDX-License-Identifier: MIT

/*
  inspired by (w) (a) (g) (m) (i) by dom
*/
import "./Love.sol";

pragma solidity ^0.8.0;

contract MyRevengeCat {
    address _owner;
    bool _birthed;
    address public LoveToken = 0x66c9AaD00A6af53A43CD317F4b4D221a035109CA;
    
    event CaretakerLoved(address indexed caretaker, uint256 indexed amount);
    
    uint256 lastFeedBlock;
    uint256 lastCleanBlock;
    uint256 lastPlayBlock;
    uint256 lastSleepBlock;
    
    uint8 internal hunger;
    uint8 internal uncleanliness;
    uint8 internal boredom;
    uint8 internal sleepiness;
    
    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }
    
    constructor() {
        _owner = msg.sender;
        lastFeedBlock = block.number;
        lastCleanBlock = block.number;
        lastPlayBlock = block.number;
        lastSleepBlock = block.number;
        
        hunger = 0;
        uncleanliness = 0;
        boredom = 0;
        sleepiness = 0;
    }
    
    function addLove(address caretaker, uint256 amount) internal {
        Love(LoveToken).mint(caretaker, amount);
        emit CaretakerLoved(caretaker, amount);
    }
    
    function feed() public {
        require(getAlive(), "no longer with us");
        require(getBoredom() < 80, "im too tired to eat");
        require(getUncleanliness() < 80, "im feeling too gross to eat");
        // require(getHunger() > 0, "i dont need to eat");
        
        lastFeedBlock = block.number;
        
        hunger = 0;
        boredom += 10;
        uncleanliness += 3;

        addLove(msg.sender, 1);
    }
    
    function clean() public {
        require(getAlive(), "no longer with us");
        require(getUncleanliness() > 0, "i dont need a bath");
        lastCleanBlock = block.number;
        
        uncleanliness = 0;
        
        addLove(msg.sender, 1);
    }
    
    function play() public {
        require(getAlive(), "no longer with us");
        require(getHunger() < 80, "im too hungry to play");
        require(getSleepiness() < 80, "im too sleepy to play");
        require(getUncleanliness() < 80, "im feeling too gross to play");
        // require(getBoredom() > 0, "i dont wanna play");
        
        lastPlayBlock = block.number;
        
        boredom = 0;
        hunger += 10;
        sleepiness += 10;
        uncleanliness += 5;
        
        addLove(msg.sender, 1);
    }
    
    function sleep() public {
        require(getAlive(), "no longer with us");
        require(getUncleanliness() < 80, "im feeling too gross to sleep");
        require(getSleepiness() > 0, "im not feeling sleepy");
        
        lastSleepBlock = block.number;
        
        sleepiness = 0;
        uncleanliness += 5;
        
        addLove(msg.sender, 1);
    }

    function revive() public {
        lastFeedBlock = block.number;
        lastCleanBlock = block.number;
        lastPlayBlock = block.number;
        lastSleepBlock = block.number;

        boredom = 0;
        hunger = 0;
        sleepiness = 0;
        uncleanliness = 0;
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
            return "The cat appears to no longer be with us. Please revive them!";
        }
        
        if (_hunger > 50 && _hunger > mostNeeded) {
            mostNeeded = _hunger;
            status = "I could use a snack..";
        }
        
        if (_uncleanliness > 50 && _uncleanliness > mostNeeded) {
            mostNeeded = _uncleanliness;
            status = "I stink. Can you bathe me?";
        }
        
        if (_boredom > 50 && _boredom > mostNeeded) {
            mostNeeded = _boredom;
            status = "I'm so bored. Play with me!";
        }
        
        if (_sleepiness > 50 && _sleepiness > mostNeeded) {
            mostNeeded = _sleepiness;
            status = "I'm tired..Can you cuddle with me?";
        }
        
        return status;
    }
    
    function getAlive() public view returns (bool) {
        return getHunger() < 101 && getUncleanliness() < 101 &&
            getBoredom() < 101 && getSleepiness() < 101;
    }
    
    function getHunger() public view returns (uint256) {
        return hunger + ((block.number - lastFeedBlock) / 50);
    }
    
    function getUncleanliness() public view returns (uint256) {
        return uncleanliness + ((block.number - lastCleanBlock) / 50);
    }
    
    function getBoredom() public view returns (uint256) {
        return boredom + ((block.number - lastPlayBlock) / 50);
    }
    
    function getSleepiness() public view returns (uint256) {
        return sleepiness + ((block.number - lastSleepBlock) / 50);
    }
}