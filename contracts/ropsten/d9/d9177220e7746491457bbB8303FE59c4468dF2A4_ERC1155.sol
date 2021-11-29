// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/presets/ERC1155PresetMinterPauserUpgradeable.sol";

import "../../utils/Ownable.sol";

contract ERC1155 is ERC1155PresetMinterPauserUpgradeable, Ownable {
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}