pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
/**
 * @dev Optional functions from the ERC20 standard.
 */
 
 contract UltraToken is ERC20PresetFixedSupply{

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address owner
    )
	ERC20PresetFixedSupply(name, symbol, initialSupply, owner)
	public
	{

	}
}