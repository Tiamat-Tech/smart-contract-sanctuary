/**
 *Submitted for verification at Etherscan.io on 2021-10-13
*/

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply = 100000000 * 10**18;

    string private _name = "altFINS";
    string private _symbol = "FINS";

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
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
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
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
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

contract FINS is ERC20 {
    mapping(address => uint256[3][12]) private _claimData;
    event Claim(
        address claimableAddress,
        uint256 amount,
        uint256 timestamp,
        address claimmer
    );

    constructor() {
        //for team
        uint256 teamAmount = (totalSupply() * 100) / 1000;
        uint256 teamFirstUnlockTime = block.timestamp + 600;

        _claimData[0x2A3d33EF0b2CdA54A77b4bf8D33622Fb77E6a555] = [
            [teamFirstUnlockTime, teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 1)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 2)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 3)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 4)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 5)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 6)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 7)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 8)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 9)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 10)), teamAmount / 12, 0],
            [teamFirstUnlockTime + ((60 * 10) * (1 * 11)), teamAmount / 12, 0]
        ];
        //end for team

        //for reserve
        uint256 rsvAmount = (totalSupply() * 50) / 1000;
        uint256 rsvFirstUnlockTime = block.timestamp + 600;

        _claimData[0x8cB760fD4A49C792bbA8395C5a6ee798e37758C7] = [
            [rsvFirstUnlockTime, rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 1)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 2)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 3)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 4)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 5)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 6)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 7)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 8)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 9)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 10)), rsvAmount / 12, 0],
            [rsvFirstUnlockTime + ((60 * 10) * (1 * 11)), rsvAmount / 12, 0]
        ];
        //end for team

        //for #1 (NIS)
        uint256 NISAmount = (totalSupply() * 56) / 1000;
        uint256 NISFirstUnlockTime = block.timestamp + 600;

        _claimData[0x77be02B2FE8db4e5C5Cf7FEd102304829A398dE1] = [
            [NISFirstUnlockTime, NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 1)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 2)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 3)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 4)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 5)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 6)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 7)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 8)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 9)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 10)), NISAmount / 12, 0],
            [NISFirstUnlockTime + ((60 * 10) * (1 * 11)), NISAmount / 12, 0]
        ];

        //end #1 (NIS)

        //for #2 (APEP)
        uint256 APEPAmount = (totalSupply() * 3492) / 100000;
        uint256 APEPFirstUnlockTime = block.timestamp + 600;

        _claimData[0xc33dBdDaA3D0B49020aA35fD552351E366fF6771] = [
            [APEPFirstUnlockTime, APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 1)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 2)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 3)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 4)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 5)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 6)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 7)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 8)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 9)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 10)), APEPAmount / 12, 0],
            [APEPFirstUnlockTime + ((60 * 10) * (1 * 11)), APEPAmount / 12, 0]
        ];

        //end #2 (APEP)

        //for #3 (CB)
        uint256 CBAmount = (totalSupply() * 4080) / 100000;
        uint256 CBFirstUnlockTime = block.timestamp + 600;

        _claimData[0xCD65a618c9f8E266696AF2951472B93529BB1bdF] = [
            [CBFirstUnlockTime, CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 1)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 2)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 3)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 4)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 5)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 6)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 7)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 8)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 9)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 10)), CBAmount / 12, 0],
            [CBFirstUnlockTime + ((60 * 10) * (1 * 11)), CBAmount / 12, 0]
        ];

        //end #2 (CB)

        //for #4 (RF)
        uint256 RFAmount = (totalSupply() * 6828) / 100000;
        uint256 RFFirstUnlockTime = block.timestamp + 600;

        _claimData[0x9b9545EBcf54A99217Dd2980B9597fb395Fd665F] = [
            [RFFirstUnlockTime, RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 1)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 2)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 3)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 4)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 5)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 6)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 7)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 8)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 9)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 10)), RFAmount / 12, 0],
            [RFFirstUnlockTime + ((60 * 10) * (1 * 11)), RFAmount / 12, 0]
        ];

        //end #4 (RF)
        uint256 total = teamAmount + rsvAmount;
        _mint(_msgSender(), totalSupply());
        _transfer(
            _msgSender(),
            address(this),
            total + APEPAmount + CBAmount + RFAmount
        );
    }

    function getAllClaimData(address claimAbleAddress)
        public
        view
        returns (uint256[3][12] memory)
    {
        return _claimData[claimAbleAddress];
    }

    function getNextClaimData(address claimAbleAddress)
        public
        view
        returns (uint256[3] memory, uint256)
    {
        return _getCurrentClaimData(claimAbleAddress);
    }

    function _getCurrentClaimData(address claimAbleAddress)
        internal
        view
        returns (uint256[3] memory result, uint256 i)
    {
        uint256[3][12] memory claimData = _claimData[claimAbleAddress];
        require(claimData.length > 0, "You cannot claim!");
        for (i = 0; i < claimData.length; i++) {
            if (claimData[i][2] == 0) {
                if (block.timestamp >= claimData[i][0]) {
                    result = claimData[i];
                    break;
                }
            }
        }
    }

    function claim(address claimAbleAddress) public returns (bool) {
        (
            uint256[3] memory currentClaimData,
            uint256 index
        ) = _getCurrentClaimData(claimAbleAddress);
        require(
            currentClaimData.length > 0,
            "claimable Address cannot claim anymore!"
        );
        require(
            block.timestamp >= currentClaimData[0],
            "claimable Address cannot claim yet!"
        );

        _transfer(address(this), claimAbleAddress, currentClaimData[1]);
        _claimData[claimAbleAddress][index][2] = 1;

        emit Claim(
            claimAbleAddress,
            currentClaimData[1],
            currentClaimData[0],
            _msgSender()
        );
        return true;
    }
}