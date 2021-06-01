// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./classes/Ownable.sol";
import "./classes/ERC20.sol";

contract LEADIA is Ownable, ERC20 {
    uint256 private _maximumSupply;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The defaut value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 maximumSupply
    ) ERC20(name, symbol) {
        _maximumSupply = maximumSupply;
        _mint(_msgSender(), initialSupply);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function mint(uint256 amount) public onlyOwner {
        require(
            (totalSupply() + amount) <= _maximumSupply,
            "Token minting limit exceeded"
        );
        _mint(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual onlyOwner {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount)
        public
        virtual
        onlyOwner
    {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}