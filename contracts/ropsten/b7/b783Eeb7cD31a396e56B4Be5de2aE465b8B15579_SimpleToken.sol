pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice This ERC20 is only for the testnet.
 */
contract SimpleToken is ERC20 {
    constructor(uint256 amount, string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(address(this), amount);
    }

    /**
     * @notice The faucet is for everyone!!
     */
    function faucet() external {
        _transfer(address(this), msg.sender, 10000 * 1e18);
    }

    
}