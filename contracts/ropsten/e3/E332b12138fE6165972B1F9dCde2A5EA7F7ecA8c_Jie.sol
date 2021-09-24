// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Jie is ERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) private lockedWallets;

    constructor() ERC20("Jie-Li", "Jie") {
//        _mint(msg.sender, 1000000 * 10**18);
        _mint(msg.sender, 1000000);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 _amount) public {
        _burn(msg.sender, _amount);
    }

    /**
     * @dev See {IERC20-lock}.
     *
     * Requirements:
     *
     * - `sender` cannot be the locked wallet.
     * - `_lockAddress` cannot be the zero address.
     */
    function lock(address _lockAddress) public onlyOwner {
        require(!lockedWallets[_lockAddress], "This wallet is locked yet");
        lockedWallets[_lockAddress] = true;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `Msg.sender` cannot be the locked wallet.
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public override returns (bool)
    {
        require(!lockedWallets[_msgSender()], "This wallet is locked");
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` cannot be the locked wallet address.
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(!lockedWallets[sender], "This sender is locked");
        _transfer(sender, recipient, amount);
        uint256 allowanced = allowance(sender, _msgSender());
        _approve(
            sender,
            _msgSender(),
            allowanced.sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }
}