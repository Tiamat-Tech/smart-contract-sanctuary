// SPDX-License-Identifier: GPL

// NFT Labs -- https://highlight.so

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract TestStablecoin is ERC20PresetMinterPauser {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC20PresetMinterPauser("TestStablecoin", "hSTABLE") {}

    function setMinter(address _manager) external {
        grantRole(MINTER_ROLE, _manager);
        revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function faucet(address _to) external {
        mint(_to, 100 ether);
    }
}