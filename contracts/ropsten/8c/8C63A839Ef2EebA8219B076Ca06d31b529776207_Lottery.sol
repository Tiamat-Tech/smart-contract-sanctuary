// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./SafeMath.sol";

contract Common {
    mapping(address => uint256) internal balances;

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}

contract Lottery is Common {
    using SafeMath for uint256;
    mapping(uint256 => address[]) public lotteryAddressMap;
    mapping(uint256 => uint256[]) public lotteryAmountMap;
    mapping(uint256 => uint8) public lotteryStatusMap; // 1 active, 2 released


    function addLottery (uint256 _id) public {
        require(lotteryStatusMap[_id] == 0, "Lottery is already exists");
        lotteryStatusMap[_id] = 1;
    }

    function particapate(uint256 _id, address _address, uint256 _amount) public {
        require(balanceOf(_address) < _amount, "Amount is not enough");
        require(lotteryStatusMap[_id] != 1, "Lottery is finished");

        lotteryAddressMap[_id].push(_address);
        lotteryAmountMap[_id].push(_amount);
    }

    function release(uint256 _id, string memory _secretRandom) public {

        

    }

    function random() public view returns(uint256){
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, uint256(123))));
    }
}