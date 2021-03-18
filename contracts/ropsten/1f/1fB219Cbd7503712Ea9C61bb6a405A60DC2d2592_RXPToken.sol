pragma solidity ^0.7.4;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract RXPToken is ERC20PresetMinterPauser {

    constructor () ERC20PresetMinterPauser("RXP Token", "RXP") {
        _setupDecimals(8);
        _mint(msg.sender, 500000000 * (10 ** uint256(decimals())));
    }
}