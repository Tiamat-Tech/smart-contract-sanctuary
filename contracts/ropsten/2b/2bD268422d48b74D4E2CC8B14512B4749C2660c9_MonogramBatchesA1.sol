// contracts/MonogramBatchesV1.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

// From base: 
// https://docs.openzeppelin.com/contracts/3.x/api/presets
import "@openzeppelin/contracts/presets/ERC1155PresetMinterPauser.sol";

contract MonogramBatchesA1 is ERC1155PresetMinterPauser {
    uint256 public constant BATCH1 = 0;
    uint256 public constant BATCH2 = 1;

    constructor() public ERC1155PresetMinterPauser("https://bftxgyfc5m.execute-api.us-west-2.amazonaws.com/dev/token/meta/{id}") {
        _mint(msg.sender, BATCH1, 10**4, "");
        _mint(msg.sender, BATCH2, 10**5, "");

    }
}