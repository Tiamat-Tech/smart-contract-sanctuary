//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
import "hardhat/console.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/GSN/Context.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/contracts/math/SafeMath.sol";
//import "./VoteContext.sol";
*/



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
//contract VotingERC20Token is VoteContext, IERC20 {
contract VotingERC20Token is IERC20, Context {    
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    //uint constant INITIAL_SUPPLY = 1000000000000000 * (10**18);    
    uint constant INITIAL_SUPPLY = 1000000000000000 * (10**2);    

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor () {
        _name = "VotingERC20Token";
        _symbol = "VOTE20T";
        //_decimals = 18;
        _decimals = 2;

        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    //WARNING: I am not sure, but it might be an issue.
    /*
    function setSender(address payable sender) external {
        console.log("VotingERC20Token, setSender, sender=%s", sender);
        _setMsgSender(sender);
    }        
   */

    function msgSender() external view returns (address payable) {
        console.log("VotingERC20Token, msgSender, _msgSender()=%s", _msgSender());
        return _msgSender();
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
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function myTransfer(address sender, address receiver, uint256 amount) public returns (bool) {
        console.log("VotingERC20Token, myTransfer, sender=%s, receiver=%s, amount=%s", sender, receiver, amount);

        require(sender != address(0), "1Not allowed zero address");
        require(receiver != address(0), "2Not allowed zero address");        
        require(amount > 0, "amount should be bigger than 0");         

        _transfer(sender, receiver, amount);
        return true;
    }


    function myAllowance(address sender, address receiver) public view returns (uint256) {
        console.log("VotingERC20Token, myAllowance, owsenderner=%s, receiver=%s, _allowances[sender][receiver]=%s", sender, receiver, _allowances[sender][receiver]);

        require(sender != address(0), "1Not allowed zero address");
        require(receiver != address(0), "2Not allowed zero address");


        return _allowances[sender][receiver];
    }


    function myApprove(address sender, address receiver, uint256 amount) public returns (bool) {
        console.log("VotingERC20Token, myApprove, sender=%s, receiver=%s, amount=%s", sender, receiver, amount);

        require(sender != address(0), "1Not allowed zero address");
        require(receiver != address(0), "2Not allowed zero address");        
        require(amount > 0, "amount should be bigger than 0"); 


        _approve(sender, receiver, amount);
        return true;
    }


    function myIncreaseAllowance(address sender, address receiver, uint256 addedValue) public returns (bool) {
        console.log("VotingERC20Token, myIncreaseAllowance, sender=%s, receiver=%s, addedValue=%s", sender, receiver, addedValue);

        require(sender != address(0), "1Not allowed zero address");
        require(receiver != address(0), "2Not allowed zero address");        
        require(addedValue > 0, "addedValue should be bigger than 0"); 


        _approve(sender, receiver, _allowances[sender][receiver].add(addedValue));
        return true;
    }

    function myDecreaseAllowance(address sender, address receiver, uint256 subtractedValue) public returns (bool) {
        console.log("VotingERC20Token, decreaseAllowance, sender=%s, receiver=%s, subtractedValue=%s", sender, receiver, subtractedValue);

        require(sender != address(0), "1Not allowed zero address");
        require(receiver != address(0), "2Not allowed zero address");        
        require(subtractedValue > 0, "amount should be bigger than 0");     

        _approve(sender, receiver, _allowances[sender][receiver].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }


    function _transfer(address sender, address receiver, uint256 amount) internal virtual {
        console.log("VotingERC20Token, _transfer, sender=%s, receiver=%s, amount=%s", sender, receiver, amount);

        require(sender != address(0), "ERC20: transfer from the zero address");
        require(receiver != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "amount should be bigger than 0");          


        _beforeTokenTransfer(sender, receiver, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[receiver] = _balances[receiver].add(amount);
        emit Transfer(sender, receiver, amount);
    }

   
    function _mint(address account, uint256 amount) internal virtual {

        console.log("VotingERC20Token, _mint, account=%s, amount=%s", account, amount);

        require(account != address(0), "ERC20: mint to the zero address");
        require(amount > 0, "amount should be bigger than 0");     

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }


    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        console.log("VotingERC20Token, _burn, account=%s, amount=%s", account, amount);

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address sender, address receiver, uint256 amount) internal virtual {
        
        console.log("VotingERC20Token, _approve, sender=%s, receiver=%s, amount=%s", sender, receiver, amount);

        require(sender != address(0), "ERC20: approve from the zero address");
        require(receiver != address(0), "ERC20: approve to the zero address");


        _allowances[sender][receiver] = amount;
        emit Approval(sender, receiver, amount);
    }

    //IMPORTANT : I am not going to use below, but just for figure out the creation issue
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
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
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
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
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
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
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }    
    //IMPORTANT : I am not going to use below, but just for figure out the creation issue



    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
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
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}