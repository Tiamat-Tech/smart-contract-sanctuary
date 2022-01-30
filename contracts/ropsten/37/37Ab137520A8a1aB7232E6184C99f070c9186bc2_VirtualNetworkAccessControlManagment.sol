/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.16 <0.7.0;
pragma experimental ABIEncoderV2;
contract VirtualNetworkAccessControlManagment
{
    string virtualnetwork;
    string idmember;
   
    struct member {
       string virtualnetwork;
       string idmember;
    }
   member[] public tabmember;
 
     
   function addmember(string memory virtualnetwork,string memory idmember) public{
         member memory m = member(virtualnetwork,idmember);
         tabmember.push(m);
   }
   function removemember(string memory virtualnetwork,string memory idmember) public{
       for ( uint i=0; i<tabmember.length;i++)
       { if( keccak256(bytes(tabmember[i].virtualnetwork))==keccak256(bytes(virtualnetwork)) 
       && keccak256(bytes(tabmember[i].idmember))==keccak256(bytes(idmember)) )
       {
           delete tabmember[i]; 
       }
   }  
   }
   function getmember(string memory virtualnetwork,string memory idmember) public view returns (string memory){
       for ( uint i=0; i<tabmember.length;i++)
       { if( keccak256(bytes(tabmember[i].virtualnetwork))==keccak256(bytes(virtualnetwork)) 
       && keccak256(bytes(tabmember[i].idmember))==keccak256(bytes(idmember)) )
       {
       return "true";
       }
      
  
       
   }
   }
}