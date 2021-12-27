// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// helpers
import "./Ownable.sol";
import "./SafeMath.sol";
import "./Pausable.sol";
import "./Context.sol";
// contract
import "./Stakeable.sol";
import "./Vendor.sol";
import "./Migration.sol";

/**
 * @notice DevToken is a development token that we use to learn how to code solidity
 * and what X interface requires
 */
contract DevToken is Context, Ownable, Pausable, Vendor, Stakeable, Migration {
    using SafeMath for uint256;

    /**
     * @notice Our Tokens required variables that are needed to operate everything
     */
    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    struct infoToken {
        uint256 _totalSupply;
        uint8 _decimals;
        string _symbol;
        string _name;
    }

    /**
     * @notice _balances is a mapping that contains a address as KEY
     * and the balance of the address as the value
     */
    mapping(address => uint256) private _balances;

    /**
     * @notice _allowances is used to manage and control allownace
     * An allowance is the right to use another accounts balance, or part of it
     */
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @notice Events are created below.
     * Transfer event is a event that notify the blockchain that a transfer of assets has taken place
     *
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @notice Approval is emitted when a new Spender is approved to spend Tokens on
     * the Owners account
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @notice constructor will be triggered when we create the Smart contract
     * _name = name of the token
     * _short_symbol = Short Symbol name for the token
     * token_decimals = The decimal precision of the Token, defaults 18
     * _totalSupply is how much Tokens there are totally
     */

    uint256 minimum_purchase_amount_staked = 10000000000; // 100 Token

    constructor(
        string memory token_name,
        string memory short_symbol,
        uint8 token_decimals,
        uint256 token_totalSupply
    ) Vendor(address(this)) {
        _name = token_name;
        _symbol = short_symbol;
        _decimals = token_decimals;

        // _totalSupply = token_totalSupply * (uint256(10)**uint256(_decimals));
        _totalSupply = token_totalSupply * 10**uint256(_decimals);
        _balances[owner()] = _totalSupply;
        _mint(address(this), 7000000 * 10**uint256(_decimals));
        // // Emit an Transfer event to notify the blockchain that an Transfer has occured
        emit Transfer(address(0), address(this), _totalSupply);
    }

    /**
     * @notice we get the token information
     */
    function getInfoToken()
        external
        view
        returns (infoToken memory _propertyObj)
    {
        return infoToken(_totalSupply, _decimals, _symbol, _name);
    }

    /**
     * @notice balanceOf will return the account balance for the given account
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice _mint will create tokens on the address inputted and then increase the total supply
     *
     * It will also emit an Transfer event, with sender set to zero address (adress(0))
     *
     * Requires that the address that is recieveing the tokens is not zero address
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "cannot mint to zero address");

        // Increase total supply
        _totalSupply = _totalSupply.add(amount);

        // Add amount to the account balance using the balance mapping
        _balances[account] = _balances[account].add(amount);

        // Emit our event to log the action
        emit Transfer(address(0), account, amount);
    }

    /**
     * @notice _burn will destroy tokens from an address inputted and then decrease total supply
     * An Transfer event will emit with receiever set to zero address
     *
     * Requires
     * - Account cannot be zero
     * - Account balance has to be bigger or equal to amount
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "cannot burn from zero address");
        require(
            _balances[account] >= amount,
            "Cannot burn more than the account owns"
        );

        // Remove the amount from the account balance
        _balances[account] = _balances[account].sub(
            amount,
            "burn amount exceeds balance"
        );

        // Decrease totalSupply
        _totalSupply = _totalSupply.sub(amount);

        // Emit event, use zero address as reciever
        emit Transfer(account, address(0), amount);
    }

    /**
     * @notice burn is used to destroy tokens on an address
     *
     * See {_burn}
     * Requires
     *   - msg.sender must be the token owner
     *
     */
    function burn(address account, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        _burn(account, amount);
        return true;
    }

    /**
     * @notice mint is used to create tokens and assign them to msg.sender
     *
     * See {_mint}
     * Requires
     *   - msg.sender must be the token owner
     *
     */
    function mint(address account, uint256 amount)
        public
        onlyOwner
        returns (bool)
    {
        _mint(account, amount);
        return true;
    }

    /**
     * @notice transfer is used to transfer funds from the sender to the recipient
     * This function is only callable from outside the contract. For internal usage see
     * _transfer
     *
     * Requires
     * - Caller cannot be zero
     * - Caller must have a balance = or bigger than amount
     *
     */
    function transfer(address recipient, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @notice _transfer is used for internal transfers
     *
     * Events
     * - Transfer
     *
     * Requires
     *  - Sender cannot be zero
     *  - recipient cannot be zero
     *  - sender balance most be = or bigger than amount
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "transfer from zero address");
        require(recipient != address(0), "transfer to zero address");
        require(
            _balances[sender] >= amount,
            "cant transfer more than your account holds"
        );

        _balances[sender] = _balances[sender].sub(
            amount,
            "transfer amount exceeds balance"
        );

        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    /**
     * @notice getOwner just calls Ownables owner function.
     * returns owner of the token
     *
     */
    function getOwner() external view returns (address) {
        return owner();
    }

    /**
     * @notice allowance is used view how much allowance an spender has
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @notice approve will use the senders address and allow the spender to use X amount of tokens on his behalf
     */
    function approve(address spender, uint256 amount)
        external
        whenNotPaused
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @notice _approve is used to add a new Spender to a Owners account
     *
     * Events
     *   - {Approval}
     *
     * Requires
     *   - owner and spender cannot be zero address
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(
            owner != address(0),
            "approve cannot be done from zero address"
        );
        require(spender != address(0), "approve cannot be to zero address");

        // Set the allowance of the spender address at the Owner mapping over accounts to the amount
        _allowances[owner][spender] = amount;

        emit Approval(owner, spender, amount);
    }

    /**
     * @notice transferFrom is uesd to transfer Tokens from a Accounts allowance
     * Spender address should be the token holder
     *
     * Requires
     *   - The caller must have a allowance = or bigger than the amount spending
     */

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external whenNotPaused returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "You cannot spend that much on this account"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    /**
     * @notice increaseAllowance
     * Adds allowance to a account from the function caller address
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        whenNotPaused
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
     * @notice decreaseAllowance
     * Decrease the allowance on the account inputted from the caller address
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        whenNotPaused
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "decreased allowance below zero"
            )
        );

        return true;
    }

    // ---------- STAKES ----------

    /**
     * Add functionality like burn to the _stake afunction
     *
     */
    function stake(
        uint256 _amount,
        uint256 _untilBlock,
        uint256 _rewardRate
    ) public whenNotPausedPresale {
        // Make sure staker actually is good for it
        require(
            _amount < _balances[_msgSender()],
            "Cannot stake more than you own"
        );

        // the initial amount must be greater than 100 jdb
        require(
            _amount >= minimum_purchase_amount_staked,
            "the initial amount must be greater than 100 jdb"
        );

        _stake(_amount, _untilBlock, _rewardRate);

        // Burn the amount of tokens on the sender
        _burn(_msgSender(), _amount);
    }

    /**
     * @notice withdrawStake is used to withdraw stakes from the account holder
     */
    function withdrawStake(uint256 amount, uint256 stake_index)
        public
        whenNotPausedPresale
    {
        uint256 amount_to_mint = _withdrawStake(amount, stake_index);
        // Return staked tokens to user
        _mint(_msgSender(), amount_to_mint);
    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */

    function totalStakes() public view returns (uint256) {
        return _totalStakes();
    }

    /**
     * @dev change minimum purchase amount
     */
    function changeMinimumStakesAmount(uint256 _minimum_purchase_amount_staked)
        public
        onlyOwner
        returns (bool)
    {
        minimum_purchase_amount_staked = _minimum_purchase_amount_staked;
        return true;
    }
}