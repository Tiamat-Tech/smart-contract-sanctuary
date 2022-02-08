// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Donation is Ownable {

    using SafeMath for uint256;

    uint256 public donationsCount;
    uint256 private totalDonations;
    address payable public withdrewAddr;
    mapping(address => Donators[]) private _donations;
    mapping(address => bool) public donatorAddrExist; 
    mapping(uint256 => address) public donatorById;
    event reciveDonations(address indexed donator, uint256 id, uint256 amount);
    uint256 public nonce;
    string public description;

    struct Donators {
        uint256 id;
        uint256 value;
        uint256 date;
        address donatorAddress;
    }

    constructor(string memory _description, address payable _withdrewAddr) {
        description = _description;
        withdrewAddr = _withdrewAddr;
    }

    function donate() public payable {
        require(msg.sender != address(0), "Invalid addresss");
        require(msg.value >= 0.001 ether, "Invalid amount, try again");
        uint _id = ++nonce;
        Donators memory donation = Donators({
            id: _id,
            value: msg.value,
            date: block.timestamp,
            donatorAddress: msg.sender
        });
        _donations[msg.sender].push(donation);
        totalDonations = totalDonations.add(msg.value);
        donatorAddrExist[msg.sender] = true;
        donatorById[_id] = msg.sender;
        donationsCount++;
        emit reciveDonations(msg.sender, _id, msg.value);
    }

    function setAddrForWithdrew(address payable _withdrewAddr) public onlyOwner {
        withdrewAddr = _withdrewAddr;
    }

    function totalDonationsCount() public view returns (uint256) {
        return donationsCount;
    }

    function totalDonationBalance() external view onlyOwner returns (uint256) {
        return totalDonations;
    }

     function chekDonatorByAddress(address _address)
        public
        view
        returns (
            uint256[] memory id,
            uint256[] memory value,
            uint256[] memory date
        )
     { 
        require(donatorAddrExist[_address], "wrong address");
        uint256 count = _donations[msg.sender].length;
        id = new uint256[](count);
        value = new uint256[](count);
        date = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            Donators memory donation = _donations[msg.sender][i];
            id[i] = donation.id;
            value[i] = donation.value;
            date[i] = donation.date;
        }
        return (id, value, date);
    }
    
    function chekDonatorById(uint256 _id) external view onlyOwner returns (address) {
    require(_id > 0, "Wrong id number");
    return donatorById[_id];
    } 

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        withdrewAddr.transfer(balance);
        totalDonations = totalDonations.sub(balance);
    }
}