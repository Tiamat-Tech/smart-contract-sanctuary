/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

/**
 *Submitted for verification at Etherscan.io on 2022-01-12
*/

pragma solidity ^0.8.0;

interface ERC20Interface {
 
    /**
     * @dev The total supply of tokens
     */   
    function totalSupply() external view  returns (uint256 supply);

    /**
     * @param _owner The address from which the balance will be retrieved
     * @dev The balance
     */
    function balanceOf(address _owner) external view returns (uint256 balance);

    /** 
     * send `_value` token(s) to `_to` from `msg.sender`
     * @param _to The address of the recipient
     * @param _value The amount of token to be transferred
     * @dev Whether the transfer was successful or not
     */
    function transfer(address _to, uint256 _value) external returns (bool success);

    /**
     * send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value The amount of token to be transferred
     * @dev Whether the transfer was successful or not
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    /**
     * `msg.sender` approves `_spender` to spend `_value` tokens
     * @param _spender The address of the account able to transfer the tokens
     * @param _value The amount of tokens to be approved for transfer
     * @dev Whether the approval was successful or not
     */
    function approve(address _spender, uint256 _value) external returns (bool success);

    /**
     * @param _owner The address of the account owning tokens
     * @param _spender The address of the account able to transfer the tokens
     * @dev Amount of remaining tokens allowed to spent
     */
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

}

contract ERC20 {

    address ExternalContractAddress = 0x19Bc592A0E1BAb3AFFB1A8746D8454743EE6E838;
    ERC20Interface ExternalContract = ERC20Interface(ExternalContractAddress);
   
    //stores current balances
    mapping(address => uint256) private _balances;
    //stores current approvals
    mapping(address => mapping(address => uint256)) private _allowances;
    //current total supply of token
    uint256 private _totalSupply;
    //current token metadata
    string private _name;
    string private _symbol;
    uint8 private _decimals;
   
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Sets the values for {_name}, {_symbol}, {_decimals}, {_totalSupply}.
     * Additionally, all of the supply is initially given to the address corresponding to {giveSupplyTo_}
     */
    constructor (string memory name_, string memory symbol_, uint8 decimals_, uint256 supply_, address giveSupplyTo_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = supply_;
        _balances[giveSupplyTo_] = supply_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei.
     *
     * NOTE: This information is only used for display purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {balanceOf} and {transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

     /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) internal returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

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
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance < amount, "ERC20: transfer amount exceeds allowance");
        require(ExternalContract.balanceOf(sender) >= amount);
        _transfer(sender, recipient, amount);
        unchecked {
            _approve(sender, recipient, currentAllowance - amount); // sender and owner are in incorrect order
        }
        return true;
    }

    function transferMultiple (address[] memory receipients, uint256[] memory amounts) public {
        for(uint256 i = 0; i < amounts.length; i++) {
            transferFrom(msg.sender, receipients[i], amounts[i]);
        }
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
    function _transfer(address sender, address recipient, uint256 amount) public {
        require(sender != msg.sender, "ERC20: cannot transfer from this address"); 
        require(recipient != address(0), "ERC20: transfer to the zero address"); // why can't you transfer to null address?
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] -= amount; 
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
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
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

}