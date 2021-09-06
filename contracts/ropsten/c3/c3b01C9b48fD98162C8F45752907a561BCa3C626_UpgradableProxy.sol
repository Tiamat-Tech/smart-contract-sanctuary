//SPDX-License-Identifier: centric lol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract UpgradableProxy is ERC721Upgradeable {
    /* All variables in data layer must be initiated in the same order as in 
        the logic layer.  All other data outside data layer does not have to be 
        initiated in any order */
    
    /* BEGIN DATA LAYER */
    uint256 testInt;
    uint256 tokenID;
    mapping(uint256 => address) public nfts;
    mapping(uint256 => Metadata) public mdata;
    struct Metadata {
        string URI;
        uint8 rarity;
    }

    
    /* END DATA LAYER */

    
    address upgradableLogic;
    bool logicSet;

    function initialize(string memory name, string memory symbol, uint256 id) initializer public {
        __ERC721_init(name, symbol);
        tokenID = id;
    }

    function setLogicAddress(address _logic) public  {
        require(upgradableLogic != _logic, "Cannot upgrade to current version");
        upgradableLogic = _logic;
        logicSet = true;
    }

    function getAddress() public view returns(address) {
        return upgradableLogic;
    }

    function _delegate() internal {
        if (!logicSet) {
            return;
        }

        assembly {
            let ptr := mload(0x40)
            
            calldatacopy(ptr, 0, calldatasize())

            let result := delegatecall(gas(), sload(upgradableLogic.slot), ptr, calldatasize(), 0, 0)

            let size := returndatasize()
            returndatacopy(ptr, 0, size)


            switch result
            case 0 {
                revert(ptr, size)

            } default {
                return(ptr, size)
            }
        }


    }
    
    fallback () external payable {
        _delegate();
    }

    receive () external payable {
        _delegate();
    }



    
}