// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./WorkspaceStorage_v1.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Workspace_v1 is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable, WorkspaceStorage_v1{

    function initialize() public initializer {
        __ERC20_init("Croissants", "CRS");
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, 200000000000000000000000 * 10 ** decimals());
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override{
    }

    event CheckedIn(address indexed _who, uint256 _spaceId);
    event TokenReturned(address indexed _to, uint256 _amountReturn);
    event GuestAdded(address indexed _who, uint _index);

    function spaceUsedTimeCalculator(uint256 entryTime) private view returns(uint256){
        return (block.timestamp-entryTime)/(3600);
    }

    function checkIn(uint256 _spaceID) payable external  returns(bool){
        Space storage space = spaces[_spaceID]; 
        require(space.available);
        require(users[msg.sender].hold == false,"Plz cancel your hold");
        // we need to send tokens worth 8 hrs to owner of space
        require(msg.value == (spaces[_spaceID].hourlyRate*8), "Please send accurate Token");
        users[msg.sender].spaceID = _spaceID;
        users[msg.sender].entryTime = block.timestamp;
        users[msg.sender].depositToken = 8;
        users[msg.sender].numGuest = 0;

        space.numActiveCheckIns++;
        space.available = (space.numSeats > space.numActiveCheckIns ? true : false);

        emit CheckedIn(msg.sender , _spaceID);
        return true;
    }

    function checkOut(uint256 _spaceID) external returns(bool){
        userInfo storage user = users[msg.sender];
        require(user.spaceID == spaces[user.spaceID].spaceID);
        uint256 spaceUsedTime =spaceUsedTimeCalculator(user.entryTime);
        for(uint i = 0; i < user.guest.length; i++ ){
            if(user.guest[i] != 0){
                spaceUsedTime += spaceUsedTimeCalculator(user.guest[i]);
            }
        }
        uint256 returnValue = (user.depositToken - spaceUsedTime)*spaces[_spaceID].hourlyRate;
        payable(msg.sender).transfer(returnValue);
        spaces[user.spaceID].numActiveCheckIns -= user.numGuest + 1;
        delete users[msg.sender];
        spaces[user.spaceID].available = true;
        emit TokenReturned(msg.sender , returnValue); 
        return true;
    }

    function addGuest() payable external returns(bool){
        // we should also add many guests at a single call...
        userInfo storage user = users[msg.sender];
        require(user.spaceID == spaces[user.spaceID].spaceID);
        uint256 spaceUsedTime = spaceUsedTimeCalculator(user.entryTime);
        require(msg.value == (spaces[user.spaceID].hourlyRate*(8-spaceUsedTime)), "Please send accurate Token");
        user.depositToken += (8-spaceUsedTime);
        user.guest.push(block.timestamp);
        user.numGuest++;

        spaces[user.spaceID].numActiveCheckIns++;
        spaces[user.spaceID].available = (spaces[user.spaceID].numSeats > spaces[user.spaceID].numActiveCheckIns ? true : false);

        emit GuestAdded(msg.sender, user.guest.length);
        return true;
    }

    function removeGuest(uint256 _index) external returns(bool){
        userInfo storage user = users[msg.sender];
        require(user.spaceID == spaces[user.spaceID].spaceID);
        require(_index < user.guest.length);
        require(user.guest[_index] != 0); // validate this condition
        uint256 entryTime = spaceUsedTimeCalculator(users[msg.sender].entryTime);
        uint256 exitTime = spaceUsedTimeCalculator(users[msg.sender].guest[_index]);
        user.depositToken -=  (8-entryTime);
        payable(msg.sender).transfer((8-(entryTime+exitTime))*spaces[user.spaceID].hourlyRate);
        delete user.guest[_index];
        user.numGuest--;
        spaces[user.spaceID].numActiveCheckIns--;
        //spaces[user.spaceID].active = true;
        return true;
    }
    function holdSeat(uint256 _spaceID) external returns(bool){
        Space storage space = spaces[_spaceID]; 
        require(space.available);
        //***we need to check if it is a valid user***
        require(users[msg.sender].hold == false);

        users[msg.sender].hold = true;
        users[msg.sender].spaceID = _spaceID;
        users[msg.sender].entryTime = block.timestamp;

        space.numActiveCheckIns++;
        space.available = (space.numSeats > space.numActiveCheckIns ? true : false);
        return true;
    }

    function cancelHold(uint256 _spaceId,address sender) external returns(bool){
        Space storage space = spaces[_spaceId]; 
        userInfo storage user = users[sender];
        require(user.hold == true);
        user.hold = false;
        user.spaceID = 0;
        user.entryTime = 0;
        space.numActiveCheckIns--;
        return true;
    }

    //function activeCheckIns() external returns(uint256) {
    //    return spaces[user.spaceID].numActiveCheckIns;
        // checks the space Id are active and return the array
   // }
    
    //function withdraw(address _to,uint256 _amount) public {
    //    require(_to==spaces.owner);
    //    transfer(msg.sender,_amount);//transfer function call to contract
        
    //}
    
}