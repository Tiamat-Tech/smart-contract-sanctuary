/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

/**
 *Submitted for verification at Etherscan.io on 2022-01-10
*/

pragma solidity ^0.5.16;

contract storageContract {
   uint public storageVar = 1;
}


contract Proxy is storageContract {

    address implementation;
    constructor(address _implementation) public {
        implementation = _implementation;
    }

    function setImplementation(address _implementation) public {
        implementation = _implementation;
    }

    function delegateStuff(uint _newVar) external returns(bytes memory){
        bytes memory data = abi.encodeWithSignature("setNewVar(uint)", _newVar);
        (bool success, bytes memory returnData) = implementation.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize)
            }
        }
        return returnData;
    }
    
}

contract Implementation is storageContract {

    function setNewVar(uint _newVar) public {
        storageVar = _newVar;
    }
    
}