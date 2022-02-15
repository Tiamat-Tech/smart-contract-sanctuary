//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";

contract Pokemon is ERC1155PresetMinterPauser {
    constructor() ERC1155PresetMinterPauser("https://pokeapi.co/api/v2/ability/{id}/") {}

    function dynamicmint(address _to, uint256 _tokenId, uint256 _amount, bytes memory _uri) external {
        mint(_to, _tokenId, _amount, _uri);
    }
}