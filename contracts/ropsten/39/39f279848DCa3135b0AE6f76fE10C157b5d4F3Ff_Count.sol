/**
 *Submitted for verification at Etherscan.io on 2021-11-30
*/

// SPDX-License-Identifier: MIT
pragma solidity >= 0.7.0 <0.9.0;

 contract Count{

     uint public count =0;

        function increment() public returns(uint){
            count +=1;
            return count;
        }

        }