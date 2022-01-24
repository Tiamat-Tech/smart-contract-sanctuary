// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract SkuskaToken is ERC20PresetFixedSupply {

    address payable private _owner;

    constructor() ERC20PresetFixedSupply(
        "SkuskaToken",
        "SKT",
        100000000000000000000000000,
        msg.sender
    ) {
        _owner = payable(msg.sender);
    }

    function close() public {
        require(msg.sender == _owner, "Sender is not owner");
        selfdestruct(_owner);
    }

}