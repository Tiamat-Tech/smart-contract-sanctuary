// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "./Contract2.sol";

contract ContractOne is ContractTwo{

    //создание сбора
    function addFundraising(string memory _name, uint _result_cost) public {
        fundraisings[msg.sender].name = _name;
        fundraisings[msg.sender].result_cost = _result_cost;
        fundraisings[msg.sender].now_cost = 0;
        fundraisings[msg.sender].work = true;
    }

    //донат на адрес
    function donate(address _addr_fund) public payable
    {
        require(fundraisings[_addr_fund].work);
        fundraisings[_addr_fund].donators[msg.sender] += msg.value;
        fundraisings[_addr_fund].now_cost += msg.value;
        if (fundraisings[_addr_fund].now_cost >= fundraisings[_addr_fund].result_cost) {
            fundraisings[_addr_fund].work = false;
        }
    }

    //получение состояния моего сбора
    function getFundraisingInfo() public view returns(string memory, uint, bool)
    {
        return (fundraisings[msg.sender].name, fundraisings[msg.sender].now_cost, fundraisings[msg.sender].work);
    }
}