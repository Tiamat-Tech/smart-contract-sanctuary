//SPDX-License-Identifier: Unlicense
// FOR TESTING ONLY, NOT TO BE DEPLOYED
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract ERC20Mock is ERC20Upgradeable {
    function initialize() public initializer {
        __ERC20_init("erc20", "erc20");
    }
    function mint(address account, uint256 amount) external {
        return _mint(account, amount);
    }
}