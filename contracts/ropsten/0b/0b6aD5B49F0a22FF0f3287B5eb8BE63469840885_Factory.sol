//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "hardhat/console.sol";

interface NumI {
  function returnUint() external returns (uint);
}

contract Factory {
  event Deployed(address _addr);

  function deploy(uint salt, bytes calldata bytecode) public {
    bytes memory implInitCode = bytecode;
    address addr;
    assembly {
        let encoded_data := add(0x20, implInitCode) // load initialization code.
        let encoded_size := mload(implInitCode)     // load init code's length.
        addr := create2(0, encoded_data, encoded_size, 0)
    }
    console.log('addr beginings', addr);
    emit Deployed(addr);
  }

  // receive() external payable {}

  //execute from there my uint//bytes calldata bytecode
  // function execute(address _numAddr) public returns (uint) {
  //   uint value = NumI(_numAddr).returnUint();
  //   return value;
  //   // console.log('HH, value', value);
  // }

  //execute from there my uint//bytes calldata bytecode
  function execute(address payable _numAddr, bytes calldata bytecode) public returns (string memory){
    // (bool success, bytes memory reason) = _numAddr.call(bytes4(sha3("sendEther()")));
    (bool success, bytes memory reason) = _numAddr.call(bytecode);

    // console.log('addr from tests', _numAddr);
    // console.log('success', success);
    // console.log('reason', string(reason));

    return string(reason);
    // return value;
    // console.log('HH, value', value);
  }

  fallback() external payable {}
}