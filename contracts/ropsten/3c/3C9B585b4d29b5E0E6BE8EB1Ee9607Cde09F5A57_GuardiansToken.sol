pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GuardiansToken is ERC20 {
    constructor() public ERC20("Guild of Guardians", "GOG") {
        _mint(0xE6d2B07c24E364ADC527124F5ba2Ae4DebD6d285, 1000000000 * 10**18);
    }
}