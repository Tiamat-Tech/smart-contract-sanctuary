//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BoxV2 is Initializable {
   struct Data {
        uint256 totalAmount;
        mapping(address => uint256) deposits;
    }
    uint256 public width;
    uint256 public length;
    mapping(address => uint256) public balances;
    mapping(uint256 => Data) public datas;
    uint256 public height;

    function initialize(uint256 _length, uint256 _width) public initializer {
        length = _length;
        width = _width;
    }

    function area() public view returns (uint256) {
        return length * width;
    }

    function setData(address _account) public {
        Data storage data = datas[0];
        data.totalAmount = 100000;
        data.deposits[_account] = 100000;
    }

    function perimeter() public view returns (uint256) {
        return length * 2 + width * 2;
    }

    function sum() public view returns (uint256) {
        return length + width + height;
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