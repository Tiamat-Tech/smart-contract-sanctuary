//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "contracts/connector.sol";

// contract Connector {

//     string private _name;

//     constructor() {
//         console.log("---Creating Contract");
//         _name = "Sekai";
//         }
    
//     function setName(string memory name) public {
//         _name = name;
//     }
//     function getName() public view returns (string memory output){
//         output = _name;
//         return output;
//     }

// }

contract ConnectorCall {

    constructor() {
        console.log("---Creating Connection");
        }
    
    function callContract(address addr) public view returns (string memory output){
        Connector c = Connector(addr);
        output = c.getName();
        return output;
    }

}