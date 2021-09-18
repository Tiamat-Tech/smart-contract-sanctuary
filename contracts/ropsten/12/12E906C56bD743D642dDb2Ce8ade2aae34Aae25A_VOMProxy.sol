// contract/VOMProxy.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VOMProxy is ERC1967Proxy {
    constructor (address _delegate, bytes memory _data )  ERC1967Proxy(_delegate, _data)  {
        
    }
    
    function upgradeTo(address newImplementation) public {
        _upgradeTo(newImplementation);
    }
}