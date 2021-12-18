pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Betrust is ERC20 {
    address public treasury;
    constructor(address _treasury, uint256 _initialSupply, uint256 _treasurySupply) ERC20("Betrust", "BTT") {
        treasury = _treasury;
        _mint(treasury, _treasurySupply);
        _mint(msg.sender, _initialSupply - _treasurySupply);
    }
}