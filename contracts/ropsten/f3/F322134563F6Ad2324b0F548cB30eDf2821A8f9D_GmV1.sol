// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract GmV1 is ERC1155 {
    uint256 public constant FAKE_RARIBLE_TOKEN = 1;
    uint256 public constant FAKE_GM_TOKEN = 706480;

    constructor() ERC1155("https://afakewebsite.org/metadata/{id}.json") {
        _mint(msg.sender, FAKE_GM_TOKEN, 10, "");
        _mint(msg.sender, FAKE_RARIBLE_TOKEN, 10, "");
    }

    function mintGm() public {
        _mint(msg.sender, FAKE_GM_TOKEN, 5, "");
    }

    function mintOther() public {
        _mint(msg.sender, FAKE_RARIBLE_TOKEN, 5, "");
    }
}