// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";
import "@imtbl/imx-contracts/contracts/IMintable.sol";


contract ImmutabloxSAUCE is ERC721, Ownable, Mintable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721(_name, _symbol) Mintable(_owner, _imx) {}


    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

}