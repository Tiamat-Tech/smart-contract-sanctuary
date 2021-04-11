/**
 *Submitted for verification at Etherscan.io on 2021-04-11
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Hodl{
    string public name_;
    address payable owner_;
	uint256 when_;

    constructor(string memory name) {
    	owner_ = payable(msg.sender);
    	name_ = name;
    	when_ = block.timestamp;
    }
    
    fallback() external payable {}

    receive() external payable {}

    function Destroy() external{
    	if (block.timestamp > when_ + 365 days) {
            owner_.transfer(address(this).balance);
            selfdestruct(owner_);
    	}
    }

}