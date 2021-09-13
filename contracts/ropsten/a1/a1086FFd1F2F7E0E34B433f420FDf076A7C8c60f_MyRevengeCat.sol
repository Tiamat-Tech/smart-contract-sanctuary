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

    using SafeMath for uint256;

    address payable public _owner;
    bool _birthed;
    address public LoveToken = 0x66c9AaD00A6af53A43CD317F4b4D221a035109CA;
    uint256 public interactPrice = 0.05 ether;
    
    event CaretakerLoved(address indexed caretaker, uint256 indexed amount);
    
    uint256 lastFeedBlock;
    uint256 lastCleanBlock;
    uint256 lastPlayBlock;
    uint256 lastSleepBlock;
    
    uint256 internal hunger;
    uint256 internal uncleanliness;
    uint256 internal boredom;
    uint256 internal sleepiness;
    
    constructor() Ownable() {

        _owner = payable(msg.sender);
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
    
    function feed() public payable {
        require(getAlive(), "It appears they are no longer with us.");
        require(getHunger() <= 75, "I'm not hungry!");
        require(msg.value >= 0.05 ether);

        _owner.transfer(msg.value);
        lastFeedBlock = block.number;
        
        hunger = hunger.add(25);
        boredom = boredom.sub(10);
        uncleanliness = uncleanliness.sub(3);

        sendLove(msg.sender, 1e18);
    }
    
    function clean() public payable {
        require(getAlive(), "It appears they are no longer with us.");
        require(getUncleanliness() <= 75, "I'm clean enough!");
        require(msg.value >= 0.05 ether);

        _owner.transfer(msg.value);

        lastCleanBlock = block.number;
        uncleanliness = uncleanliness.add(25);
        
        sendLove(msg.sender, 1e18);
    }
    
    function play() public payable {
        require(getAlive(), "It appears they are no longer with us.");
        require(getBoredom() <= 75, "I'm not bored");
        require(msg.value >= 0.05 ether);

        _owner.transfer(msg.value);
        
        lastPlayBlock = block.number;
        
        boredom = boredom.add(25);
        hunger = hunger.sub(10);
        sleepiness = sleepiness.sub(10);
        uncleanliness =  uncleanliness.sub(5);

        sendLove(msg.sender, 1e18);
    }
    
    function sleep() public payable {
        require(getAlive(), "It appears they are no longer with us.");
        require(getSleepiness() >= 75, "I'm not sleepy at all!");
        require(msg.value >= 0.05 ether);

        _owner.transfer(msg.value);
        
        lastSleepBlock = block.number;
        
        sleepiness = sleepiness.add(25);
        uncleanliness = uncleanliness.sub(5);
        
        sendLove(msg.sender, 1e18);
    }

    function revive() public payable {
        require(!getAlive(), "I'm not dead, what are you doing?");
        require(msg.value >= 0.05 ether);

        _owner.transfer(msg.value);

        lastFeedBlock = block.number;
        lastCleanBlock = block.number;
        lastPlayBlock = block.number;
        lastSleepBlock = block.number;

        boredom = 100;
        hunger = 100;
        sleepiness = 100;
        uncleanliness = 100;
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
        return hunger.sub(block.number.sub(lastFeedBlock)).div(50);
    }
    
    function getUncleanliness() public view returns (uint256) {
        return uncleanliness.sub(block.number.sub(lastCleanBlock)).div(50);
    }
    
    function getBoredom() public view returns (uint256) {
        return boredom.sub(block.number.sub(lastPlayBlock)).div(50);
    }
    
    function getSleepiness() public view returns (uint256) {
        return sleepiness.sub(block.number.sub(lastSleepBlock)).div(50);
    }
}