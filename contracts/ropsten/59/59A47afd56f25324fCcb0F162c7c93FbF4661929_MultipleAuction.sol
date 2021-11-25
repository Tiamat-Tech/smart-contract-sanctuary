//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
contract MultipleAuction
{
    address public highestbidder;
    struct bidder
    {
       
        uint bidamunt;
        uint bid;
    }
    struct auction
    {
        bool ended;
        string benificaryname;
        string description;
        uint auctionendtime;
        uint bid;
    }
    uint public highestbid;
    event loghighestbidincreas(address bidder,uint amount);
    event logauctionended(address winner , uint amount);
    mapping (address=>uint)public pendingreturns;
     mapping(address => bidder) public bidders;
     mapping(address =>auction)public  benificary;
     address payable public owner;
     constructor(string memory _benificaryname,string memory _description,uint _auctionendtime,address payable _owner)
     {
        owner=_owner;
        benificary[owner].benificaryname=_benificaryname;
        benificary[owner].description=_description;
        benificary[owner].auctionendtime= _auctionendtime;
        
     }
function createauction(address auctioncreater) public 
{
   auction storage sender =benificary[msg.sender];
   sender.auctionendtime=benificary[owner].auctionendtime+block.timestamp;
   sender.description=benificary[owner].description;
   sender.benificaryname=benificary[owner].benificaryname;
   sender.ended=false;

}
    function bid(uint bid)public payable
    {
        bidder storage sender = bidders[msg.sender];
      if(block.timestamp>benificary[msg.sender].auctionendtime)
      {
          revert("the auction already ended");
      }
      if(msg.value<=highestbid)
      {
          revert("this is already high bid");
      }
      if(highestbid!=0)
      {
        pendingreturns[highestbidder]+=highestbid;  
      }
      highestbidder=msg.sender;
      highestbid=msg.value;
      emit loghighestbidincreas(msg.sender,msg.value);
    }
     function auctionend(uint bid) public
    {
        if(block.timestamp<benificary[msg.sender].auctionendtime)
        {
            revert("the auction has not ended yet");
        }
        if(benificary[msg.sender].ended)
        {
         revert("the auction fumction has already called");   
        }
        benificary[msg.sender].ended=true;
        emit logauctionended(highestbidder,highestbid);
        owner.transfer(highestbid);
    }
}