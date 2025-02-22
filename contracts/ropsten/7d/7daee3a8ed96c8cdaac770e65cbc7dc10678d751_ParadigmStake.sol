pragma solidity ^0.5.0;

// File: openzeppelin-solidity/contracts/token/ERC20/IERC20.sol

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: openzeppelin-solidity/contracts/math/SafeMath.sol

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {
    int256 constant private INT256_MIN = -2**255;

    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring &#39;a&#39; not being zero, but the
        // benefit is lost if &#39;b&#39; is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Multiplies two signed integers, reverts on overflow.
    */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring &#39;a&#39; not being zero, but the
        // benefit is lost if &#39;b&#39; is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == INT256_MIN)); // This is the only case of overflow not detected by the check below

        int256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold

        return c;
    }

    /**
    * @dev Integer division of two signed integers truncating the quotient, reverts on division by zero.
    */
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0); // Solidity only automatically asserts when dividing by 0
        require(!(b == -1 && a == INT256_MIN)); // This is the only case of overflow

        int256 c = a / b;

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Subtracts two signed integers, reverts on overflow.
    */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Adds two signed integers, reverts on overflow.
    */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

// File: openzeppelin-solidity/contracts/ownership/Ownable.sol

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0));
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/Observer.sol

interface Observer {
    function balanceUpdate(address _token, address _account, int _change) external;
}

// File: openzeppelin-solidity/contracts/token/ERC20/ERC20.sol

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 * Originally based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 *
 * This implementation emits additional Approval events, allowing applications to reconstruct the allowance status for
 * all accounts just by listening to said events. Note that this isn&#39;t required by the specification, and other
 * compliant implementations may not do it.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;

    /**
    * @dev Total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    /**
    * @dev Transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        _transfer(from, to, value);
        emit Approval(from, msg.sender, _allowed[from][msg.sender]);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].add(addedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed_[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = _allowed[msg.sender][spender].sub(subtractedValue);
        emit Approval(msg.sender, spender, _allowed[msg.sender][spender]);
        return true;
    }

    /**
    * @dev Transfer token for a specified addresses
    * @param from The address to transfer from.
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param account The account that will receive the created tokens.
     * @param value The amount that will be created.
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account.
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0));

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Internal function that burns an amount of the token of a given
     * account, deducting from the sender&#39;s allowance for said account. Uses the
     * internal burn function.
     * Emits an Approval event (reflecting the reduced allowance).
     * @param account The account whose tokens will be burnt.
     * @param value The amount that will be burnt.
     */
    function _burnFrom(address account, uint256 value) internal {
        _allowed[account][msg.sender] = _allowed[account][msg.sender].sub(value);
        _burn(account, value);
        emit Approval(account, msg.sender, _allowed[account][msg.sender]);
    }
}

// File: contracts/Token.sol

contract Token is ERC20, Ownable {

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    constructor(string memory _name, string memory _symbol) public {
        name = _name;
        symbol = _symbol;
    }

    function burn(uint amount) public onlyOwner {
        _burn(msg.sender, amount);
    }

    function mint(uint amount) public onlyOwner {
        _mint(msg.sender, amount);
    }
}

// File: contracts/Treasury.sol

contract Treasury is Ownable {
    using SafeMath for uint;

    Token public digm;
    mapping(address => uint) private digmBalances;
    Token public nickl;
    mapping(address => uint) private nicklBalances;
    Token public penny;
    mapping(address => uint) private pennyBalances;

    mapping(address => bool) private whitelist;
    mapping(address => address[]) listeners;

    constructor() public {
        digm = new Token("DIGM", "DIGM");
        nickl = new Token("NICKL", "NICKL");
        penny = new Token("PENNY", "PENNY");
        whitelist[msg.sender] = true;
    }

    function deposit(address token, address account, uint amount) onlyWhitelisted public {
        require(IERC20(token).transferFrom(account, address(this), amount));
        notifyObservers(token, account, int(amount));
        setBalance(token, account, getBalance(token, account).add(amount));
    }

    function withdraw(address token, address account, uint amount) onlyWhitelisted public {
        require(getBalance(token, account) >= amount);
        require(IERC20(token).transfer(account, amount));
        notifyObservers(token, account, int(amount) * -1);
        setBalance(token, account, getBalance(token, account).sub(amount));
    }

    function updateBalance(address token, address account, uint amount) onlyWhitelisted public {
        uint currentBalance = getBalance(token, account);
        if(currentBalance > amount) {
            uint amountToWithdraw = currentBalance.sub(amount);
            withdraw(token, account, amountToWithdraw);
        } else if (currentBalance < amount) {
            uint amountToDeposit = amount.sub(currentBalance);
            deposit(token, account, amountToDeposit);
        }
    }

    function adjustBalance(address token, address account, int amount) onlyWhitelisted public {
        if(amount < 0) {
            withdraw(token, account, uint(amount * -1));
        } else if (amount > 0) {
            deposit(token, account, uint(amount));
        }
    }

    function currentBalance(address token, address account) public view returns (uint)  {
        return getBalance(token, account);
    }

    function currentBalances(address account) public view returns (uint, uint, uint) {
        return (digmBalances[account], nicklBalances[account], pennyBalances[account]);
    }

    function split(uint amount) public {
        require(digm.transferFrom(msg.sender, address(this), amount));

        digm.burn(amount);
        nickl.mint(amount);
        penny.mint(amount);

        require(nickl.transfer(msg.sender, amount));
        require(penny.transfer(msg.sender, amount));
    }

    function merge(uint amount) public {
        require(nickl.transferFrom(msg.sender, address(this), amount));
        require(penny.transferFrom(msg.sender, address(this), amount));


        nickl.burn(amount);
        penny.burn(amount);
        digm.mint(amount);

        require(digm.transfer(msg.sender, amount));
    }

    function addListener(address token, address _contract) onlyOwner public {
        if(isListening(token, _contract)) return;

        listeners[token].push(_contract);
    }

    function removeListener(address token, address _contract) onlyOwner public {
        for(uint i = 0; i < listeners[token].length; i++) {
            if(listeners[token][i] == _contract) {
                if(i == listeners[token].length - 1) {
                    listeners[token].length--;
                } else {
                    listeners[token][i] = listeners[token][listeners[token].length - 1];
                    listeners[token].length--;
                }
            }
        }
    }

    function whitelistAccount(address account) onlyOwner public {
        whitelist[account] = true;
    }

    function blacklistAccount(address account) onlyOwner public {
        whitelist[account] = false;
    }

    function ownerTokenTransfer(address token, address recipient, uint amount) onlyOwner public {
        IERC20(token).transfer(recipient, amount);
    }

    function mintDigm(uint amount) onlyOwner public {
        digm.mint(amount);
    }

//  INTERNAL
    function isListening(address token, address _contract) internal view returns (bool) {
        for(uint i = 0; i < listeners[token].length; i++) {
            if(listeners[token][i] == _contract) return true;
        }
        return false;
    }

    function notifyObservers(address token, address account, int change) internal {
        for(uint i = 0; i < listeners[token].length; i++) {
            if(listeners[token][i] != msg.sender) {
                Observer(listeners[token][i]).balanceUpdate(token, account, change);
            }
        }
    }

    function getBalance(address token, address account) internal view returns (uint) {
        if(token == address(digm)) {
            return digmBalances[account];
        }

        if(token == address(nickl)) {
            return nicklBalances[account];
        }

        if(token == address(penny)) {
            return pennyBalances[account];
        }
    }

    function setBalance(address token, address account, uint amount) internal {
        if(token == address(digm)) {
            digmBalances[account] = amount;
        }

        if(token == address(nickl)) {
            nicklBalances[account] = amount;
        }

        if(token == address(penny)) {
            pennyBalances[account] = amount;
        }
    }

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender]);
        _;
    }
}

// File: contracts/ParadigmStake.sol

contract ParadigmStake is Observer {
    using SafeMath for uint;

    uint public totalStaked = 0;
    address public token;
    Treasury private treasury;

    event StakeMade(address staker, uint amount);
    event StakeRemoved(address staker, uint amount);

    constructor(address _treasury) public {
        treasury = Treasury(_treasury);
        token = address(treasury.penny());
    }

    function stake(uint amount) public {
        treasury.deposit(token, msg.sender, amount);
        totalStaked = totalStaked.add(amount);
        emit StakeMade(msg.sender, amount);
    }

    function removeStake(uint amount) public {
        treasury.withdraw(token, msg.sender, amount);
        totalStaked = totalStaked.sub(amount);
        emit StakeRemoved(msg.sender, amount);
    }

    function stakeFor(address a) public view returns (uint) {
        return treasury.currentBalance(token, a);
    }

    function balanceUpdate(address _token, address _account, int _change) external {
        if(_change < 0) {
            emit StakeRemoved(_account, uint(_change * -1));
        } else {
            emit StakeMade(_account, uint(_change));
        }
    }
}