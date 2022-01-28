/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.8.11;

interface MyCounter {
    function count() external view returns (uint);

    function add() external;
}

contract TestInterface {
    function useCountAdd(address _counterAddress) public {
        MyCounter(_counterAddress).add();
    }

    function getValueCount(address _counterAddress) public view returns (uint) {
        return MyCounter(_counterAddress).count();
    }
}