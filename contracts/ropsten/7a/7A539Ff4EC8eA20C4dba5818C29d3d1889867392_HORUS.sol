// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./classes/Ownable.sol";
import "./classes/ERC20.sol";

contract HORUS is Ownable, ERC20 {
    uint256 private _maximumSupply;
    uint8 private _decimals;

    /** The contract can be initialized with a number of tokens
     *  All the tokens are deposited to the owner address
     */
    constructor() ERC20("HORUS", "HRT") {
        uint256 decimalsToken = 3;
        uint256 initialSupply = 8888889 * (10**decimalsToken);
        uint256 maximumSupply = 177777780 * (10**decimalsToken);

        _maximumSupply = maximumSupply;
        _decimals = uint8(decimalsToken);
        _mint(_msgSender(), initialSupply);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * @param amount Number of tokens to be minted
     * Emits a {Transfer} event with `from` set to the zero address.
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
     * @param amount Number of tokens to be burned
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual onlyOwner {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     * @param account The address to burned tokens
     * @param amount Number of tokens to be burned
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

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}