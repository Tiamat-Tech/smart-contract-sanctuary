pragma solidity 0.6.12;

import "./libs/ERC20.sol";
import "./libs/ERC20Burnable.sol";
import "./libs/ERC20Capped.sol";


contract ONUSToken is ERC20Burnable, ERC20Capped {

    uint256 private totalTokens = 40000000 * 10 ** 18;
    address private masterWallet = 0x4102a799B5b87Db21F7707e2Cc2789330254397F;

    constructor() public ERC20("ONUS", "ONUS") ERC20Capped(totalTokens){
        ERC20._mint(msg.sender, totalTokens);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override(ERC20, ERC20Capped) {
        super._beforeTokenTransfer(from, to, amount);
    }
}