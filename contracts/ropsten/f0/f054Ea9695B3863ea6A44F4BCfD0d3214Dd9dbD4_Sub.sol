//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Sub is Ownable {
    using Counters for Counters.Counter;

    struct Subscription {
        uint256 price;
        uint256 time;
    }

    struct User_Details {
        bool isSubscribed;
        uint256 end_of_subscription;
    }

    uint256 constant private SECONDS_IN_DAY = 86400;
    uint256 private currentPrice = 10;
    address payable public treasury;
    uint maxNumberOfUsers = 2;
    uint numberOfUsers;
    uint currentSubscriptions;
    
    mapping(address => User_Details) private users;
    mapping(address => bool) private whitelisted;
    mapping(uint => Subscription) private subscriptionOptions;
    address[] currentlySubscribedAddresses;

    bool public paused; 

    constructor() {
        subscriptionOptions[0] = Subscription(10, 14 * SECONDS_IN_DAY);
        subscriptionOptions[1] = Subscription(15, 30 * SECONDS_IN_DAY);
        subscriptionOptions[2] = Subscription(20, 90 * SECONDS_IN_DAY);
        subscriptionOptions[3] = Subscription(25, 365 * SECONDS_IN_DAY);
        subscriptionOptions[69] = Subscription(10, 10);
        //0.00000000000000001
    }
    
    function setTreasury(address payable _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function setBasePrice(uint256 _index, uint256 _price) external onlyOwner {
        subscriptionOptions[_index].price = _price;
    }

    function getSubscriptionLength(uint256 _index) external view returns(uint256) {
        return subscriptionOptions[_index].time;
    }

    function setSubscriptionLength(uint256 _index, uint256 _timeInDays) external onlyOwner {
        subscriptionOptions[_index].time = _timeInDays * SECONDS_IN_DAY;
    }

    function purchase() external payable {
        require(treasury != address(0), "Treasury not set yet.");
        require(currentPrice == msg.value, "Incorrect Ether value.");
        require(!paused, "Sale is not active. Check Discord or Twitter for updates.");
        require(!whitelisted[msg.sender], "You have already purchased. Use subscribe function.");
        require(numberOfUsers < maxNumberOfUsers, "All keys have been purchased. Check Discord or Twitter for updates.");
        
        User_Details storage user = users[msg.sender];

        //gives user 30 days for free with first purchase
        //currently hardcoded to test time (500 seconds)
        user.end_of_subscription = block.timestamp + subscriptionOptions[69].time;
        user.isSubscribed = true;

        numberOfUsers++;
        currentSubscriptions++;
        currentlySubscribedAddresses.push(msg.sender);
        whitelisted[msg.sender] = true;

        treasury.transfer(msg.value);
    }

    function subscribe(uint256 _subscriptionIndex) external payable {
        require(treasury != address(0), "Treasury not set yet.");
        require(subscriptionOptions[_subscriptionIndex].price == msg.value, "Incorrect Ether value.");
        require(!paused, "Sale is not active. Check Discord or Twitter for updates.");
        require(whitelisted[msg.sender], "You are not whitelisted. Use purchase function.");
        //change this later to 4
        require(_subscriptionIndex < 70);

        User_Details storage user = users[msg.sender];

        if (getTimeUntilSubscriptionExpired(msg.sender) <= 0 && !user.isSubscribed) {
            // time left is 0 or negative (current time + subscription time)
            // and the user wasnt subscribed
            user.end_of_subscription = block.timestamp + subscriptionOptions[_subscriptionIndex].time;
            user.isSubscribed = true;
            currentSubscriptions++;
        } else if(getTimeUntilSubscriptionExpired(msg.sender) <= 0) {
            // time left is 0 or negative (current time + subscription time)
            user.end_of_subscription = block.timestamp + subscriptionOptions[_subscriptionIndex].time;
        } else {
            //time still left on the subscription
            user.end_of_subscription += subscriptionOptions[_subscriptionIndex].time;
        }

        // Never hold Ether in the contract. Directly transfer 5% to the referrer, 95% to the treasury wallet.
        // Can change this to a function to send all at once to save gas...
        treasury.transfer(msg.value);
    }

    function getSubscriptionPlanPrice(uint _index) external view returns(uint256) {
        return subscriptionOptions[_index].price;
    }

    function setMaxNumberOfUsers(uint _numberOfUsers) external onlyOwner {
        maxNumberOfUsers = _numberOfUsers;
    }
 
    function getMaxNumberOfUsers() external view returns(uint) {
        return maxNumberOfUsers;
    }

    function getTimeUntilSubscriptionExpired(address _address) public view returns(int256) {
        return int256(users[_address].end_of_subscription) - int256(block.timestamp);
    }

    function getNumberOfActiveSubscriptions() external view returns(uint) {
        return currentSubscriptions;
    }

    function updateNumberOfSubscribers() external {
        uint index = 0;
        User_Details storage user;

        while (index < currentlySubscribedAddresses.length) {
            user = users[currentlySubscribedAddresses[index]];
            while (user.isSubscribed && getTimeUntilSubscriptionExpired(currentlySubscribedAddresses[index]) <= 0) {
                currentSubscriptions--;
                user.isSubscribed = false;
            }
            index++;

        }
    }

    function subscribed(address _address) external view returns(bool) {
        User_Details storage user = users[_address];
        return user.isSubscribed;
    }

    function efficientRemove(uint _index) internal {
        require(_index < currentlySubscribedAddresses.length);
        users[currentlySubscribedAddresses[_index]].end_of_subscription = 0;
        whitelisted[currentlySubscribedAddresses[_index]] = false;
        currentlySubscribedAddresses[_index] = currentlySubscribedAddresses[currentlySubscribedAddresses.length - 1];
        currentlySubscribedAddresses.pop();
        numberOfUsers--;
    }

    function getWhitelistedAddresses() external view returns(address[] memory) {
        return currentlySubscribedAddresses;
    }

    function removeAddressFromWhitelist(address _address) external onlyOwner {
        for (uint i = 0; i < currentlySubscribedAddresses.length; i++) {
            if (currentlySubscribedAddresses[i] == _address) {
                efficientRemove(i);
            }
        }
    }

    function isPaused() external view returns(bool) {
        return paused;
    }

    function setPaused(bool _paused) external onlyOwner {
        //require(msg.sender == owner, "You are not the owner");
        paused = _paused;
    }

    function getNumberOfWhitelistedUsers() external view returns(uint) {
        return numberOfUsers;
    }
    
}

// CHANGE SOME OF THE FUNCTIONS TO ALLOW A DECIMAL FOR TESTING
// CURRENTLY CAN ONLY USE WHOLE NUMBERS UINT256