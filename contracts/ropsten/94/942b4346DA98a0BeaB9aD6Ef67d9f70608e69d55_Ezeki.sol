// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Ezeki is Initializable{

    string public nickname;
    string public avatarId;

    function initialize(string memory _nickname, string memory _avatarId) public initializer {
        nickname = _nickname;
        avatarId = _avatarId;
    }

    function setNickname(string memory _nickname) public {
        nickname = _nickname;
    }

    function getNickname() public view returns (string memory){
        return nickname;
    }

    function sayHi() public pure returns (string memory) {
        return "Hello World 4";
    }

    function sum(int256 a, int256 b) public pure returns (int256) {
        return a + b;
    }
}