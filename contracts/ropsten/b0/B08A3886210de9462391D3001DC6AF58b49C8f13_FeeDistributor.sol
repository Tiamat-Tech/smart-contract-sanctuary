// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract FeeDistributor {

    uint256 public immutable share1;
    uint256 public immutable share2;

    uint256 public totalDistributed1;
    uint256 public totalDistributed2;

    address public immutable address1;
    address public immutable address2;

    event SentTo(address account, uint256 amount);

    constructor(address _address1, address _address2, uint256 _share1,uint256 _share2) {
        address1 = _address1;
        address2 = _address2;
        share1 = _share1;
        share2 = _share2;
    }

    function distribute() public {
        uint256 balance = address(this).balance;
        uint256 amount1 = balance * 80 / 100;
        uint256 amount2 = balance - amount1;
        (bool success, ) = address1.call{value: amount1}("");
        (success, ) = address2.call{value: amount2}("");
        if (success) {
            totalDistributed1 += amount1;
            totalDistributed2 += amount2;
            emit SentTo(address1, amount1);
            emit SentTo(address2, amount2);
        }

    }

    receive() payable external {
    }
}