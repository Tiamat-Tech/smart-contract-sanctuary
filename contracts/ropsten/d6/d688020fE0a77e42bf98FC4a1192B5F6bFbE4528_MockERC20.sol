pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is ERC20Upgradeable {
    function initialize(string memory name, string memory symbol, uint256 _initalSupply) public initializer {
        __ERC20_init(name, symbol);
        _mint(msg.sender, _initalSupply);
    }
}