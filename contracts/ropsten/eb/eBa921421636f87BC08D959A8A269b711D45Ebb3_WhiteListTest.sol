pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WhiteListTest is Ownable {
    address[] whiteListArr;

    function getWhitelist() public view returns(address[] memory) {
        return whiteListArr;
    }

    function setWhiteList(address[] memory _arr) public onlyOwner {
        whiteListArr = _arr;
    }
}