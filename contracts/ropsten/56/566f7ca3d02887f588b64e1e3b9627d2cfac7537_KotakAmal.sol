/**
 *Submitted for verification at Etherscan.io on 2021-09-24
*/

/**
 *Submitted for verification at Etherscan.io on 2021-09-22
*/

/**
 *Submitted for verification at BscScan.com on 2021-09-14
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0;

contract Ownable
{	
// Variable that maintains
// owner address
address private _owner;

// Sets the original owner of
// contract when it is deployed
constructor()
{
	_owner = msg.sender;
}

// Publicly exposes who is the
// owner of this contract
function owner() public view returns(address)
{
	return _owner;
}

// onlyOwner modifier that validates only
// if caller of function is contract owner,
// otherwise not
modifier onlyOwner()
{
	require(isOwner(),
	"Function accessible only by the owner !!");
	_;
}

// function for owners to verify their ownership.
// Returns true for owners otherwise false
function isOwner() public view returns(bool)
{
	return msg.sender == _owner;
}
}

contract KotakAmal is Ownable{
    
    event LogDonate(address sender, uint amount);
    event LogWithdrawal(address sender, uint amount);

    function donate() public payable returns(bool success) {
        emit LogDonate(msg.sender, msg.value);
        return true;
    }
    
    function getDonationBalance() public view returns(uint balance) {
        return address(this).balance;
    }
    
    function withdrawMoney() public onlyOwner{
        address payable to = payable(msg.sender);
        to.transfer(getDonationBalance());
    }

    
}