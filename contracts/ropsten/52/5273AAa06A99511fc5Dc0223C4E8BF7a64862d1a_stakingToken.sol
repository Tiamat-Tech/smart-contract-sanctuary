pragma solidity ^0.5.16;

// import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";



contract stakingToken is ERC20Pausable, ERC20Mintable, ERC20Detailed {
	constructor(string memory _name, string memory _symbol, uint8 decimals)
	ERC20Detailed(_name, _symbol, decimals)
    ERC20Pausable()
	public
	{
		_mint(msg.sender, 999999999 * 10 ** 9);
	}

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public whenNotPaused returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    // function unpause() public onlyPauser whenPaused {
    //     super.unpause();
    // }
}