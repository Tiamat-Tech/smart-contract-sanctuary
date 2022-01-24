// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract Asset is ERC721, Mintable {
    constructor(

    ) ERC721("test", "tt") Mintable(0xbe5475C0BBC2F06Be89C1bceFE16CD488C5Bd70f, 0x68e6217A0989c5e2CBa95142Ada69bA1cE2cdCA9) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }
}