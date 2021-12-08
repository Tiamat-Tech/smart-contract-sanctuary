/**
 *Submitted for verification at Etherscan.io on 2021-12-08
*/

//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7;


contract test {
    event Test(address _sender, uint256 _amount);
    event TestInput(uint256 _id, bytes32 _blob, string _test);

    uint256 public total;
    
    fallback () external payable {
        require(msg.value >= 0.05 ether, "Not enough ether sent!");
        
        uint256 amount = msg.value / 0.05 ether;
        
        emit Test(msg.sender, amount);
    }
    
    function buy(uint256 amount) public payable {
        require(msg.value == 0.005 ether, "Not enough Ether!");
        
        emit Test(msg.sender, amount);
    }
    
    function set_total(uint256 tot) public {
        total = tot;
    }

    function test_inputs(uint256 id, bytes32 blob, string memory _test) public {
        emit TestInput(id, blob, _test);
    }
}