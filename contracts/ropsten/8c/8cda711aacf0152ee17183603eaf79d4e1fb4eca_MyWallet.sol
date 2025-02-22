/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.7;

contract MyWallet
{
    // address payable, поскольку на него должен быть отправлен кредит, а также списываться деньги
    address payable owner;
    
    constructor()
    {
        owner = payable(msg.sender);
    }
    
    function callPayable(address payable _adr) public payable {
        require(msg.sender == owner);
        _adr.call{value: msg.value}("");
    }

}