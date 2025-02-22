// File: @openzeppelin/contracts/utils/Context.sol

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/5dfe7215a9156465d550030eadc08770503b2b2f/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract extraFunctions is Ownable {
    mapping(uint256 => productStruct) _product;

    struct productStruct {
        bool whitelistEnabled;
        mapping(address => bool) isWhitelisted;
    }

    //mapping(address => bool) isWhitelisted;

    function whitelist(uint256 productId, address[] memory _addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            _product[productId].isWhitelisted[_addresses[i]] = true;
        }
    }

    function removeWhitelist(uint256 productId, address[] memory _addresses)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < _addresses.length; i++) {
            _product[productId].isWhitelisted[_addresses[i]] = false;
        }
    }

    function setProductWhitelistEnabled(uint256 productId, bool _state)
        public
        onlyOwner
    {
        _product[productId].whitelistEnabled = _state;
    }

    function isProductWhitelistEnabled(uint256 productId)
        public
        view
        returns (bool)
    {
        return _product[productId].whitelistEnabled;
    }

    function getProductAddressIsWhitelisted(uint256 productId, address _address)
        public
        view
        returns (bool)
    {
        return _product[productId].isWhitelisted[_address];
    }
}

// File: @openzeppelin/contracts/utils/Context.sol

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

pragma solidity >=0.6.0 <0.8.0;

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

// File: @openzeppelin/contracts/math/SafeMath.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol

pragma solidity >=0.6.0 <0.8.0;

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
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
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
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
        _totalSupply = 1000000000000000000000000;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
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
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
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
            _allowances[_msgSender()][spender].add(addedValue)
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
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
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

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
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
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
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

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
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
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
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
}

// File: @openzeppelin/contracts/utils/Pausable.sol

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() internal {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: contracts/utils/Ownable.sol

pragma solidity >=0.6.0;

// File: contracts/StakingContract.sol

pragma solidity >=0.6.0;

contract StakingContract2 is Pausable, Ownable, ERC20, extraFunctions {
    using SafeMath for uint256;

    mapping(uint256 => ProductAPR) public products; /* Available Products */
    uint256[] public productIds; /* Available Product Ids*/
    mapping(address => uint256[]) public mySubscriptions; /* Address Based Subcriptions */
    uint256 incrementId = 0;
    uint256 lockedTokens = 0;

    uint256 private constant year = 365 days;

    //address public sCoinAddress;
    address public teamFeeReceiver;
    uint256 farmStart;

    ERC20 public erc20;

    SCOIN public sCoinAddress;

    address public erc721;

    extraFunctions public _extraFunctions;

    struct SubscriptionAPR {
        uint256 _id;
        uint256 productId;
        uint256 startDate;
        uint256 endDate;
        uint256 amount;
        address subscriberAddress;
        uint256 APR; /* APR for this product */
        bool finalized;
        uint256 withdrawAmount;
    }

    struct ProductAPR {
        address tokenAddress;
        bool sCoinState;
        bool feeState;
        uint256 createdAt;
        uint256 startDate;
        uint256 endDate;
        uint256 totalMaxAmount;
        uint256 individualMaximumAmount; /* FIX PF */
        uint256 APR; /* APR for this product */
        uint256 currentAmount;
        bool lockedUntilFinalization; /* Product can only be withdrawn when finalized */
        address[] subscribers;
        uint256[] subscriptionIds;
        mapping(uint256 => SubscriptionAPR) subscriptions; /* Distribution object */
    }

    //uint256 farmStart;

    struct Ranges {
        uint256 rangeOneStart;
        uint256 rangeOneEnd;
        uint256 rangeOneNFT;
        uint256 rangeOneFee;
        uint256 rangeTwoStart;
        uint256 rangeTwoEnd;
        uint256 rangeTwoNFT;
        uint256 rangeTwoFee;
        uint256 rangeThreeStart;
        uint256 rangeThreeEnd;
        uint256 rangeThreeNFT;
        uint256 rangeThreeFee;
        uint256 rangeFourthStart;
        uint256 rangeFourthEnd;
        uint256 rangeFourthNFT;
        uint256 rangeFourthFee;
    }

    mapping(uint256 => Ranges) subscriptionRanges;

    // set first and second ranges and variables for sub id
    function setRangesForID1(
        uint256 subId,
        uint256 _rangeStartOne,
        uint256 _rangeEndOne,
        uint256 _rangeOneNFT,
        uint256 _rangeOneFee,
        uint256 _rangeStartTwo,
        uint256 _rangeEndTwo,
        uint256 _rangeTwoNFT,
        uint256 _rangeTwoFee
    ) public onlyOwner {
        subscriptionRanges[subId].rangeOneStart = _rangeStartOne;
        subscriptionRanges[subId].rangeOneEnd = _rangeEndOne;
        subscriptionRanges[subId].rangeOneNFT = _rangeOneNFT;
        subscriptionRanges[subId].rangeOneFee = _rangeOneFee;

        subscriptionRanges[subId].rangeTwoStart = _rangeStartTwo;
        subscriptionRanges[subId].rangeTwoEnd = _rangeEndTwo;
        subscriptionRanges[subId].rangeTwoNFT = _rangeTwoNFT;
        subscriptionRanges[subId].rangeTwoFee = _rangeTwoFee;
    }

    // set third and fourth ranges and variables for sub id
    function setRangesForID2(
        uint256 subId,
        uint256 _rangeThreeStart,
        uint256 _rangeThreeEnd,
        uint256 _rangeThreeNFT,
        uint256 _rangeThreeFee,
        uint256 _rangeFourthStart,
        uint256 _rangeFourthEnd,
        uint256 _rangeFourthNFT,
        uint256 _rangeFourthFee
    ) public onlyOwner {
        subscriptionRanges[subId].rangeThreeStart = _rangeThreeStart;
        subscriptionRanges[subId].rangeThreeEnd = _rangeThreeEnd;
        subscriptionRanges[subId].rangeThreeNFT = _rangeThreeNFT;
        subscriptionRanges[subId].rangeThreeFee = _rangeThreeFee;

        subscriptionRanges[subId].rangeFourthStart = _rangeFourthStart;
        subscriptionRanges[subId].rangeFourthEnd = _rangeFourthEnd;
        subscriptionRanges[subId].rangeFourthNFT = _rangeFourthNFT;
        subscriptionRanges[subId].rangeFourthFee = _rangeFourthFee;
    }

    function checkFirstRangeForID(uint256 _Id) public view returns (bool) {
        if (
            block.timestamp >=
            farmStart + subscriptionRanges[_Id].rangeOneStart * 1 minutes &&
            block.timestamp <=
            farmStart + subscriptionRanges[_Id].rangeOneEnd * 1 minutes
        ) return true;

        return false;
    }

    function checkSecondRangeForID(uint256 _Id) public view returns (bool) {
        if (
            block.timestamp >=
            farmStart + subscriptionRanges[_Id].rangeTwoStart * 1 minutes &&
            block.timestamp <=
            farmStart + subscriptionRanges[_Id].rangeTwoEnd * 1 minutes
        ) return true;

        return false;
    }

    function checkThirdRangeForID(uint256 _Id) public view returns (bool) {
        if (
            block.timestamp >=
            farmStart + subscriptionRanges[_Id].rangeThreeStart * 1 minutes &&
            block.timestamp <=
            farmStart + subscriptionRanges[_Id].rangeThreeEnd * 1 minutes
        ) return true;

        return false;
    }

    function checkFourthRangeForID(uint256 _Id) public view returns (bool) {
        if (
            block.timestamp >=
            farmStart + subscriptionRanges[_Id].rangeFourthStart * 1 minutes &&
            block.timestamp <=
            farmStart + subscriptionRanges[_Id].rangeFourthEnd * 1 minutes
        ) return true;

        return false;
    }

    function getStats(uint256 product_id)
        public
        view
        returns (uint256, uint256)
    {
        //if(firstRange()) {
        if (checkFirstRangeForID(product_id)) {
            return (
                subscriptionRanges[product_id].rangeOneNFT,
                subscriptionRanges[product_id].rangeOneFee
            );
        } else if (checkSecondRangeForID(product_id)) {
            return (
                subscriptionRanges[product_id].rangeTwoNFT,
                subscriptionRanges[product_id].rangeTwoFee
            );
        } else if (checkThirdRangeForID(product_id)) {
            return (
                subscriptionRanges[product_id].rangeThreeNFT,
                subscriptionRanges[product_id].rangeThreeFee
            );
        } else if (checkFourthRangeForID(product_id)) {
            return (
                subscriptionRanges[product_id].rangeFourthNFT,
                subscriptionRanges[product_id].rangeFourthFee
            );
        } else return (0, 0); // default nft requried and fees are 0 */
    }

    function getSubIDFirstRange(uint256 id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            subscriptionRanges[id].rangeOneStart,
            subscriptionRanges[id].rangeOneEnd,
            subscriptionRanges[id].rangeOneNFT,
            subscriptionRanges[id].rangeOneFee
        );
    }

    function getSubIDSecondRange(uint256 id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            subscriptionRanges[id].rangeTwoStart,
            subscriptionRanges[id].rangeTwoEnd,
            subscriptionRanges[id].rangeTwoNFT,
            subscriptionRanges[id].rangeTwoFee
        );
    }

    function getSubIDThirdRange(uint256 id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            subscriptionRanges[id].rangeThreeStart,
            subscriptionRanges[id].rangeThreeEnd,
            subscriptionRanges[id].rangeThreeNFT,
            subscriptionRanges[id].rangeThreeFee
        );
    }

    function getSubIDFourthRange(uint256 id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            subscriptionRanges[id].rangeFourthStart,
            subscriptionRanges[id].rangeFourthEnd,
            subscriptionRanges[id].rangeFourthNFT,
            subscriptionRanges[id].rangeFourthFee
        );
    }

    constructor(
        address _tokenAddress,
        address _nftAddress,
        address _teamFeeReceiver,
        extraFunctions ExtraFunctions
    ) public ERC20("sCoin", "sCoin") {
        erc20 = ERC20(_tokenAddress);
        erc721 = _nftAddress;
        teamFeeReceiver = _teamFeeReceiver;
        farmStart = block.timestamp;

        _extraFunctions = ExtraFunctions;

        //sCoinAddress = address(new SCOIN());

        sCoinAddress = new SCOIN();
        farmStart = block.timestamp;
    }

    /* Current Held Tokens */
    function heldTokens() public view returns (uint256) {
        return erc20.balanceOf(address(this));
    }

    /* Locked Tokens for the APR */
    function futureLockedTokens() public view returns (uint256) {
        return lockedTokens;
    }

    /* Available Tokens to he APRed by future subscribers */
    function availableTokens() public view returns (uint256) {
        return heldTokens().sub(futureLockedTokens());
    }

    function subscribeProduct(uint256 _product_id, uint256 _amount)
        external
        whenNotPaused
    {
        if (_extraFunctions.isProductWhitelistEnabled(_product_id) == true)
            _checkWhitelist(_product_id, msg.sender);

        IERC20 _address = IERC20(products[_product_id].tokenAddress);

        uint256 time = block.timestamp;
        /* Confirm Amount is positive */
        require(_amount > 0, "Amount has to be bigger than 0");

        (uint256 nfthold, ) = getStats(_product_id);

        require(
            IERC721(erc721).balanceOf(msg.sender) >= nfthold,
            "Must hold at least product's required NFTs"
        );

        /* Confirm product still exists */
        require(
            block.timestamp < products[_product_id].endDate,
            "Already ended the subscription"
        );

        /* Confirm Subscription prior to opening */
        if (block.timestamp < products[_product_id].startDate) {
            time = products[_product_id].startDate;
        }

        /* Confirm the user has funds for the transfer */
        require(
            _amount <= _address.allowance(msg.sender, address(this)),
            "Spender not authorized to spend this tokens, allow first"
        );

        /* Confirm Max Amount was not hit already */
        require(
            products[_product_id].totalMaxAmount >
                (products[_product_id].currentAmount + _amount),
            "Max Amount was already hit"
        );

        /* Confirm Amount is smaller than maximum Amount */
        /* FIX PF */
        require(
            _amount <= products[_product_id].individualMaximumAmount,
            "Has to be smaller than maximum"
        );

        uint256 futureAPRAmount = getAPRAmount(
            products[_product_id].APR,
            time,
            products[_product_id].endDate,
            _amount
        );

        /* Confirm the current funds can assure the user the APR is valid */
        require(
            availableTokens() >= futureAPRAmount,
            "Available Tokens has to be higher than the future APR Amount"
        );

        /* Confirm the user has funds for the transfer */
        require(
            _address.transferFrom(msg.sender, address(this), _amount),
            "Transfer Failed"
        );

        if (products[_product_id].sCoinState == true)
            sCoinAddress.mint(msg.sender, _amount);

        /* Add to LockedTokens */
        lockedTokens = lockedTokens.add(_amount.add(futureAPRAmount));

        uint256 subscription_id = incrementId;
        incrementId = incrementId + 1;

        /* Create SubscriptionAPR Object */
        SubscriptionAPR memory subscriptionAPR = SubscriptionAPR(
            subscription_id,
            _product_id,
            time,
            products[_product_id].endDate,
            _amount,
            msg.sender,
            products[_product_id].APR,
            false,
            0
        );

        /* Create new subscription */
        mySubscriptions[msg.sender].push(subscription_id);
        products[_product_id].subscriptionIds.push(subscription_id);
        products[_product_id].subscriptions[subscription_id] = subscriptionAPR;
        products[_product_id].currentAmount =
            products[_product_id].currentAmount +
            _amount;
        products[_product_id].subscribers.push(msg.sender);
    }

    function _checkWhitelist(uint256 product_id, address sender) internal view {
        require(
            _extraFunctions.getProductAddressIsWhitelisted(
                product_id,
                sender
            ) == true,
            "You are not whitelisted for this product"
        );
    }

    function createProduct(
        address _address,
        bool _sCoinState,
        bool _feeState,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _totalMaxAmount,
        uint256 _individualMaximumAmount,
        uint256 _APR,
        bool _lockedUntilFinalization
    ) external whenNotPaused onlyOwner {
        /* Confirmations */
        require(block.timestamp < _endDate, "timestamp < endDate");
        require(block.timestamp <= _startDate, "timestamp <= startDate");
        require(_startDate < _endDate, "start < end");
        require(_totalMaxAmount > 0, "total max amount");
        require(_individualMaximumAmount > 0, "individ max amount");
        require(
            _totalMaxAmount > _individualMaximumAmount,
            "total max > individ max amount"
        );
        require(_APR > 0, "apr");
        require(_address != address(0), "zero address");

        address[] memory addressesI;
        uint256[] memory subscriptionsI;

        /* Create ProductAPR Object */
        ProductAPR memory productAPR = ProductAPR(
            _address,
            _sCoinState,
            _feeState,
            block.timestamp,
            _startDate,
            _endDate,
            _totalMaxAmount,
            _individualMaximumAmount,
            _APR,
            0,
            _lockedUntilFinalization,
            addressesI,
            subscriptionsI
        );

        uint256 product_id = productIds.length + 1;

        /* Add Product to System */
        productIds.push(product_id);
        products[product_id] = productAPR;
    }

    function getAPRAmount(
        uint256 _APR,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _amount
    ) public pure returns (uint256) {
        return
            ((_endDate.sub(_startDate)).mul(_APR).mul(_amount)).div(
                year.mul(100)
            );
    }

    function getProductIds() public view returns (uint256[] memory) {
        return productIds;
    }

    function getMySubscriptions(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return mySubscriptions[_address];
    }

    function withdrawSubscription(uint256 _product_id, uint256 _subscription_id)
        external
        whenNotPaused
    {
        /* Confirm Product exists */
        require(products[_product_id].endDate != 0, "Product has expired");

        /* Confirm Subscription exists */
        require(
            products[_product_id].subscriptions[_subscription_id].endDate != 0,
            "Product does not exist"
        );

        /* Confirm Subscription is not finalized */
        require(
            products[_product_id].subscriptions[_subscription_id].finalized ==
                false,
            "Subscription was finalized already"
        );

        /* Confirm Subscriptor is the sender */
        require(
            products[_product_id]
                .subscriptions[_subscription_id]
                .subscriberAddress ==
                msg.sender ||
                msg.sender == owner,
            "Not the subscription owner"
        );

        SubscriptionAPR memory subscription = products[_product_id]
            .subscriptions[_subscription_id];

        /* Confirm start date has already passed */
        require(
            block.timestamp > subscription.startDate,
            "Now is below the start date"
        );

        /* Confirm end date for APR */
        uint256 finishDate = block.timestamp;
        /* Verify if date has passed the end date */
        if (block.timestamp >= products[_product_id].endDate) {
            finishDate = products[_product_id].endDate;
        } else {
            /* Confirm the Product can be withdrawn at any time */
            require(
                products[_product_id].lockedUntilFinalization == false,
                "Product has to close to be withdrawned"
            );
        }

        uint256 tokensTowithdraw;

        if (products[_product_id].sCoinState == true) {
            if (
                msg.sender ==
                products[_product_id]
                    .subscriptions[_subscription_id]
                    .subscriberAddress
            ) {
                require(
                    sCoinAddress.balanceOf(subscription.subscriberAddress) > 0,
                    "Subscriber must hold sCoin to unsubscribe"
                );
                tokensTowithdraw = sCoinAddress.balanceOf(
                    subscription.subscriberAddress
                );
            } else if (msg.sender == owner) {
                require(
                    sCoinAddress.balanceOf(owner) > 0,
                    "Owner must hold sCoin to unsubscribe"
                );
                tokensTowithdraw = sCoinAddress.balanceOf(owner);
                if (sCoinAddress.balanceOf(owner) > subscription.amount)
                    tokensTowithdraw = subscription.amount;
            }
        } else {
            // if sCoin state == false
            tokensTowithdraw = subscription.amount;
        }

        uint256 APRedAmount = getAPRAmount(
            subscription.APR,
            subscription.startDate,
            finishDate,
            subscription.amount
        );
        require(APRedAmount > 0, "APR amount has to be bigger than 0");
        uint256 totalAmount = tokensTowithdraw.add(APRedAmount);
        uint256 totalAmountWithFullAPR = tokensTowithdraw.add(
            getAPRAmount(
                subscription.APR,
                subscription.startDate,
                products[_product_id].endDate,
                subscription.amount
            )
        );
        require(totalAmount > 0, "Total Amount has to be bigger than 0");

        /* Update Subscription */
        products[_product_id].subscriptions[_subscription_id].finalized = true;
        products[_product_id]
            .subscriptions[_subscription_id]
            .endDate = finishDate;
        products[_product_id]
            .subscriptions[_subscription_id]
            .withdrawAmount = totalAmount;

        /* Transfer funds to the subscriber address */

        address _address = products[_product_id].tokenAddress;

        (, uint256 feeVal) = getStats(_product_id);

        // if withdraw within X days of farm start and fee of this product is enabled, take fee
        if (products[_product_id].feeState == true && msg.sender != owner) {
            // apply X % fee if withdraw within X days of farm start
            uint256 rewardFee = APRedAmount.mul(feeVal).div(100);
            uint256 rewardAmt = APRedAmount.sub(rewardFee);
            uint256 stakedFee = tokensTowithdraw.mul(feeVal).div(100);
            uint256 stakedAmt = tokensTowithdraw.sub(stakedFee);

            require(
                erc20.transfer(teamFeeReceiver, rewardFee),
                "Transfer has failed"
            );
            require(
                erc20.transfer(subscription.subscriberAddress, rewardAmt),
                "Transfer has failed"
            );

            require(
                IERC20(_address).transfer(teamFeeReceiver, stakedFee),
                "Transfer has failed"
            );
            require(
                IERC20(_address).transfer(
                    subscription.subscriberAddress,
                    stakedAmt
                ),
                "Transfer has failed"
            );

            if (products[_product_id].sCoinState == true)
                sCoinAddress.burn(
                    subscription.subscriberAddress,
                    tokensTowithdraw
                );
        } else {
            if (msg.sender == owner) {
                require(
                    IERC20(_address).transfer(owner, tokensTowithdraw),
                    "Transfer has failed"
                );
                if (products[_product_id].sCoinState == true)
                    sCoinAddress.burn(owner, tokensTowithdraw);
            } else {
                require(
                    IERC20(_address).transfer(
                        subscription.subscriberAddress,
                        tokensTowithdraw
                    ),
                    "Transfer has failed"
                );
                require(
                    erc20.transfer(subscription.subscriberAddress, APRedAmount),
                    "Transfer has failed"
                );
                if (products[_product_id].sCoinState == true)
                    sCoinAddress.burn(
                        subscription.subscriberAddress,
                        tokensTowithdraw
                    );
            }
        }

        /* Sub to LockedTokens */
        lockedTokens = lockedTokens.sub(totalAmountWithFullAPR);
    }

    function getSubscription(uint256 _subscription_id, uint256 _product_id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256,
            bool,
            uint256
        )
    {
        SubscriptionAPR memory subscription = products[_product_id]
            .subscriptions[_subscription_id];

        return (
            subscription._id,
            subscription.productId,
            subscription.startDate,
            subscription.endDate,
            subscription.amount,
            subscription.subscriberAddress,
            subscription.APR,
            subscription.finalized,
            subscription.withdrawAmount
        );
    }

    function getProductFirstEight(uint256 _product_id)
        external
        view
        returns (
            address,
            bool,
            bool,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        ProductAPR memory product = products[_product_id];

        (uint256 nftval, uint256 feeNow) = getStats(_product_id);

        return (
            product.tokenAddress,
            product.sCoinState,
            product.feeState,
            nftval,
            feeNow,
            product.createdAt,
            product.startDate,
            product.endDate
        );
    }

    function getProductRest(uint256 _product_id)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            address[] memory,
            uint256[] memory
        )
    {
        ProductAPR memory product = products[_product_id];

        return (
            product.totalMaxAmount,
            product.individualMaximumAmount,
            product.APR,
            product.currentAmount,
            product.lockedUntilFinalization,
            product.subscribers,
            product.subscriptionIds
        );
    }

    function setProductFeeState(uint256 _productId, bool _state)
        public
        onlyOwner
    {
        products[_productId].feeState = _state;
    }

    function setProductSCoinState(uint256 _productId, bool _state)
        external
        onlyOwner
    {
        products[_productId].sCoinState = _state;
    }

    function safeGuardAllTokens(address _tokenAddress, address _address)
        external
        onlyOwner
        whenPaused
    {
        /* In case of needed urgency for the sake of contract bug */
        require(
            IERC20(_tokenAddress).transfer(
                _address,
                IERC20(_tokenAddress).balanceOf(address(this))
            )
        );
    }

    function withdrawTokens(address _tokenAddress, uint256 _amount)
        external
        onlyOwner
    {
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) > 0,
            "There are no tokens to withdraw"
        );

        require(
            IERC20(_tokenAddress).transfer(owner, _amount),
            "Transfer has failed"
        );
    }

    function changeTokenAddress(address _tokenAddress)
        external
        onlyOwner
        whenPaused
    {
        /* If Needed to Update the Token Address (ex : token swap) */
        erc20 = ERC20(_tokenAddress);
    }
}

contract SCOIN is ERC20, Ownable {
    address public farmingContract;
    using SafeMath for uint256;

    constructor() public ERC20("sCoin", "sCoin") {
        farmingContract = _msgSender();
    }

    function mint(address _to, uint256 amount) public {
        require(
            farmingContract == msg.sender,
            "You are not authorised to mint"
        );
        _mint(_to, amount);
    }

    function burn(address account, uint256 amount) public {
        require(
            farmingContract == msg.sender,
            "You are not authorised to burn"
        );
        _burn(account, amount);
    }
}