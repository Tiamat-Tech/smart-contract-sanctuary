//SPDX-License-Identifier: centric lol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MasterProxy {
    //uint256 testInt;
    address upgradableProxy;
    bool proxySet;

    string public version;


    function setUpgradableProxyAddress(address implementation) public  {
        require(upgradableProxy != implementation, "Cannot upgrade to current version");
        upgradableProxy = implementation;
        proxySet = true;
        
    }

    function getAddress() public view returns (address) {
        return upgradableProxy;
    }

    function _delegate() internal {
        if (!proxySet) {
            return;
        }

        assembly {
            
            calldatacopy(0, 0, calldatasize())

            let result := call(gas(), sload(upgradableProxy.slot), 0, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())


            switch result
            case 0 {
                revert(0, returndatasize())

            } default {
                return(0, returndatasize())
            }
        }


    }
    
    receive () external payable {
        _delegate();
    }

    fallback () external payable  {
        _delegate();
    }
}