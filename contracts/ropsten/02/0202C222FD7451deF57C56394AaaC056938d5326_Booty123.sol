// SPDX-License-Identifier: MIT
//A Pixel Piracy Project - BOOTY IS A UTILITY TOKEN FOR THE PIXEL PIRACY ECOSYSTEM.
//$BOOTY is NOT an investment and has NO economic value.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IPirates {
    function balanceOf(address account) external view returns(uint256);
}

contract Booty123 is ERC20, Ownable {
    IPirates public Pirates;
    address public Chests;

    uint256 constant public BASE_RATE = 10 ether;
    uint256 public START;
    bool rewardPaused = false;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastUpdate;

    mapping(address => bool) public allowedAddresses;

    constructor() ERC20("Booty123", "BOOTY123") {
        START = block.timestamp;
    }

    function setPirates(address pirateAddress) public onlyOwner {
        Pirates = IPirates(pirateAddress);
    }
    
    function setChests(address chestAddress) public onlyOwner {
        Chests = chestAddress;
    }

    function updateReward(address from, address to) external {
        require(msg.sender == address(Pirates));
        if(from != address(0)){
            rewards[from] += getPendingReward(from);
            lastUpdate[from] = block.timestamp;
        }
        if(to != address(0)){
            rewards[to] += getPendingReward(to);
            lastUpdate[to] = block.timestamp;
        }
    }

    function claimReward() external {
        require(!rewardPaused, "Claiming reward has been paused"); 
        _mint(msg.sender, rewards[msg.sender] + getPendingReward(msg.sender));
        rewards[msg.sender] = 0;
        lastUpdate[msg.sender] = block.timestamp;
    }

    function burn(address user, uint256 amount) external {
        require(allowedAddresses[msg.sender] || msg.sender == address(Pirates) || msg.sender == address(Chests), "Address does not have permission to burn");
        _burn(user, amount);
    }
    
    function mint(address user, uint256 amount) external {
        require(allowedAddresses[msg.sender] || msg.sender == address(Pirates) || msg.sender == address(Chests), "Address does not have permission to mint");
        _mint(user, amount);
    }

    function getTotalClaimable(address user) external view returns(uint256) {
        return rewards[user] + getPendingReward(user);
    }

    function getPendingReward(address user) internal view returns(uint256) {
        return Pirates.balanceOf(user) * BASE_RATE * (block.timestamp - (lastUpdate[user] >= START ? lastUpdate[user] : START)) / 86400;
    }

    function setAllowedAddresses(address _address, bool _access) public onlyOwner {
        allowedAddresses[_address] = _access;
    }

    function toggleReward() public onlyOwner {
        rewardPaused = !rewardPaused;
    }
}