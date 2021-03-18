pragma solidity ^0.7.4;

// import "@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract RXPToken is ERC20PresetMinterPauser {

    constructor () ERC20PresetMinterPauser("RRRToken", "RRR") {
        _setupDecimals(8);
        _mint(msg.sender, 500000000 * (10 ** uint256(decimals())));
    }
}

//