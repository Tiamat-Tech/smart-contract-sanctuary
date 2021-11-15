// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract Gopnik is ERC721, Mintable {
    constructor(address _owner, address _imx)
        ERC721("Gopnik", "GPK")
        Mintable(_owner, _imx)
    {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }
}