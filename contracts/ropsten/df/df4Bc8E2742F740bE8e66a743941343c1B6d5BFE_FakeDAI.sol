// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract FakeDAI is ERC20PresetMinterPauser {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC20PresetMinterPauser("FakeDAI", "fDAI") {}
}