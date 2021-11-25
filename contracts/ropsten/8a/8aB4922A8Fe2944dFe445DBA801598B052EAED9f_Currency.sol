//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.1;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract Currency is ERC1155Upgradeable {

    uint256 private constant _FRC = 5;
    uint256 private constant _TRC = 10; 

    function init() public initializer {
        address _owner = msg.sender;
        _mint(_owner, _FRC, 10**21, "");
        _mint(_owner, _TRC, 10**21, "");
    }
    
}