// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (proxy/Proxy.sol)

pragma solidity ^0.8.0;
import "./proxy.sol";
 contract Bridge is Proxy{
     address owner;
    function Symbol() public pure returns(string memory) {
        return "br";
    }
    function _implementation() internal  view  override returns (address){
        return owner;
    }
     function _beforeFallback() internal override {

     }
}