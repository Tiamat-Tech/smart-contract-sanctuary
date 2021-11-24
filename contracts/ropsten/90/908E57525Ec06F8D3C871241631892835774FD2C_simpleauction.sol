//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
contract simpleauction
{
    address payable public beneficary;
    //String  public description;
    //String public benificaryname;
    uint public minimumbidding;
    uint public maximumbidding;
    uint public auctionendtime;
    address public highestbidder;
    uint public highestbid;
    mapping (address=>uint)public pendingreturns;
    bool ended=false;
    event loghighestbidincreas(address bidder,uint amount);
    event logauctionended(address winner , uint amount);
    constructor(uint _biddingtime,address payable _beneficary,uint _minimumbidding,uint _maximumbidding)
    {
       beneficary=_beneficary;
       auctionendtime=block.timestamp+_biddingtime;
     //  benificaryname=_benificaryname;
      // description=_description;
       minimumbidding=_minimumbidding;
       maximumbidding=_maximumbidding;
    }
    function bid ()public payable
    {
      if(block.timestamp>auctionendtime)
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
    function withdraw()public returns(bool)
    {
        uint amount =pendingreturns[msg.sender];
        if(amount>0)
        {
            pendingreturns[msg.sender]=0;
            if(!payable(msg.sender).send(amount))
            {
                pendingreturns[msg.sender]=amount;
                return false;
            }
        }
        return true;
    }
    function auctionend() public
    {
        if(block.timestamp<auctionendtime)
        {
            revert("the auction has not ended yet");
        }
        if(ended)
        {
         revert("the auction fumction has already called");   
        }
        ended=true;
        emit logauctionended(highestbidder,highestbid);
        beneficary.transfer(highestbid);
    }
}