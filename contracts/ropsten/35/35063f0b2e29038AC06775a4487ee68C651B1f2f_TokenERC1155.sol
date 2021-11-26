// contracts/GameItems.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC1155.sol";
import "./Ownable.sol";
import "./Strings.sol";
import "./ERC1155PresetMinterPauser.sol";

contract TokenERC1155 is ERC1155, Ownable {
    


    uint256 public constant lilpeep = 0;
    uint256 public constant xxx = 1;
    uint256 public constant bones = 2;
    uint256 public constant scar = 3;
    
    mapping (uint256 => string) private _uris;

    constructor() public ERC1155("https://bafybeibfw4ax36cqsvdtmxnl53cijjxu5m7kujtfvbvfunyibz26n4ifye.ipfs.dweb.link/") {
        _mint(msg.sender, lilpeep, 1000, "");
        _mint(msg.sender, xxx, 1000, "");
        _mint(msg.sender, bones, 1000, "");
        _mint(msg.sender, scar, 1000, "");
    }
    
    function uri(uint256 tokenId) override public view returns (string memory) {
        return(_uris[tokenId]);
    }
       
    
}