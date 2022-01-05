//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BoxV1 is Initializable {
    struct Data {
        uint256 totalAmount;
        mapping(address => uint256) deposits;
    }
    uint256 public width;
    uint256 public length;
    mapping(address => uint256) public balances;
    mapping(uint256 => Data) public datas;

    function initialize(uint256 _length, uint256 _width) public initializer {
        length = _length;
        width = _width;
        balances[msg.sender] = 1;
    }

    function area() public view returns (uint256) {
        return length * width;
    }

    function setData(address _account) public {
        Data storage data = datas[0];
        data.totalAmount = 100000;
        data.deposits[_account] = 100000;
    }

    function getTotalAmount() public view returns (uint256) {
       Data storage data = datas[0];
        return data.totalAmount;
    }

    function getDeposit(address _account) public view returns (uint256) {
        Data storage data = datas[0];
        return data.deposits[_account];
    }
}