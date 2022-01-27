// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract MyToken is ERC721, Ownable,Mintable {

    string public baseTokenURI;

    constructor() ERC721("Rufus", "RF")  Mintable(0xbe5475C0BBC2F06Be89C1bceFE16CD488C5Bd70f, 0x68e6217A0989c5e2CBa95142Ada69bA1cE2cdCA9) {}



    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }



    

     function setBaseTokenURI(string memory uri) public onlyOwner {
        baseTokenURI = uri;
    }

       function _mintFor(
        address to,
        uint256 id,
        bytes calldata blueprint
    ) internal override {
        _safeMint(to, id);
    }
}