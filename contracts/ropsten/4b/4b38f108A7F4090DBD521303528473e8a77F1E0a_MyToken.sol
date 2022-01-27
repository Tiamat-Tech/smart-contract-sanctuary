// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract MyToken is ERC721, Ownable,Mintable {

    string public baseTokenURI;

    constructor() ERC721("Rufus", "RF")  Mintable(0xbe5475C0BBC2F06Be89C1bceFE16CD488C5Bd70f, 0x4527BE8f31E2ebFbEF4fCADDb5a17447B27d2aef) {}




function _baseURI() internal pure override returns (string memory) {
        return "https://4b56907172a9.ngrok.io/";
    }

    

     function setBaseTokenURI(string memory uri) public onlyOwner {
        baseTokenURI = uri;
    }



       function _mintFor(
        address to,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(to, id);
    }


    
}