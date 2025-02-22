pragma solidity ^0.4.24;
/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


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
/**
 * @title SafeMath
 * @dev Math operations (only add and sub here) with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}
contract TOTToken is ERC20, Pausable {

  using SafeMath for uint256;

  string public name = "Trecento";      //  token name
  string public symbol = "TOT";           //  token symbol
  uint256 public decimals = 18;            //  token digit




  uint256 private totalSupply_;
  bool public mintingFinished = false;

  uint256 public cap = 20000000 * 10 ** decimals; // Max cap 20.000.000 token

  mapping(address => uint256) private balances;

  mapping (address => mapping (address => uint256)) private allowed;



  event Burn(address indexed burner, uint256 value);
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  modifier canMint() {
    require(!mintingFinished);
    _;
  }



  /**
    * @dev Change token name, Owner only.
    * @param _name The name of the token.
  */
  function setName(string _name)  public onlyOwner {
    name = _name;
  }

  /**
    * @dev Change token symbol, Owner only.
    * @param _symbol The symbol of the token.
  */
  function setSymbol(string _symbol)  public onlyOwner {
    symbol = _symbol;
  }


  /**
    * @dev total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return totalSupply_;
  }

  /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

  /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public whenNotPaused returns (bool success) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);
    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    emit Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint256 the amount of tokens to be transferred
  */
  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    emit Transfer(_from, _to, _value);
    return true;
  }

  /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    *
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards:
    * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
  */
  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    allowed[msg.sender][_spender] = _value;
    emit Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
    * @dev Function to check the amount of tokens that an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
  */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }

  /**
    * @dev Increase the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _addedValue The amount of tokens to increase the allowance by.
  */
  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
    * @dev Decrease the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To decrement
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _subtractedValue The amount of tokens to decrease the allowance by.
  */
  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Function to 	mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount)  public onlyOwner canMint returns (bool) {
    require(_amount > 0);
    require(totalSupply_.add(_amount) <= cap);
    require(_to != address(0));
    totalSupply_ = totalSupply_.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    emit Mint(_to, _amount);
    emit Transfer(address(0), _to, _amount);
    return true;
  }

  /**
 * @dev Function to stop minting new tokens.
 * @return True if the operation was successful.
 */
function finishMinting()  public onlyOwner canMint returns (bool) {
  mintingFinished = true;
  emit MintFinished();
  return true;
}




  /**
    * @dev Burns a specific amount of tokens.
    * @param _value The amount of token to be burned.
  */
  function burn(uint256 _value) public whenNotPaused {
    require(_value <= balances[msg.sender]);
    // no need to require value <= totalSupply, since that would imply the
    // sender&#39;s balance is greater than the totalSupply, which *should* be an assertion failure

    address burner = msg.sender;
    balances[burner] = balances[burner].sub(_value);
    totalSupply_ = totalSupply_.sub(_value);
    emit Burn(burner, _value);
    emit Transfer(burner, address(0), _value);
  }


}
contract Distribute is Ownable{

  using SafeMath for uint256;
  // Token distribution, must sumup to 1000
  uint256 public constant SHARE_PURCHASERS = 75;
  uint256 public constant SHARE_FOUNDATION = 5;
  uint256 public constant SHARE_TEAM = 15;
  uint256 public constant SHARE_BOUNTY = 5;
  TOTToken public token;

  // Wallets addresses
  address public foundationAddress;
  address public teamAddress;
  address public bountyAddress;

  // Versting
  uint256 public releasedTokens;
  uint256 public tokensTorelease;
  uint256 public startVesting;
  uint256 public period1;
	uint256 public period2;
	uint256 public period3;
  uint256 public period4;
  bool public distributed_round1 = false;
  bool public distributed_round2 = false;
  bool public distributed_round3 = false;
  bool public distributed_round4 = false;

  constructor(address _token, address _foundationAddress, address _teamAddress, address _bountyAddress) public {
    require(_token != address(0) && _foundationAddress != address(0) && _teamAddress != address(0) && _bountyAddress != address(0));
    token = TOTToken(_token);
    foundationAddress = _foundationAddress;
    teamAddress = _teamAddress;
    bountyAddress = _bountyAddress;
  }

  function updateWallets(address _foundation, address _team, address _bounty) public onlyOwner {
    require(!token.mintingFinished());
    require(_foundation != address(0) && _team != address(0) && _bounty != address(0));
    foundationAddress = _foundation;
    teamAddress = _team;
    bountyAddress = _bounty;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() public onlyOwner returns (bool) {

    // before calling this method totalSupply includes only purchased tokens
    uint256 total = token.totalSupply().mul(100).div(SHARE_PURCHASERS); //ignore (totalSupply mod 617) ~= 616e-8,

    uint256 foundationTokens = total.mul(SHARE_FOUNDATION).div(100);
    uint256 teamTokens = total.mul(SHARE_TEAM).div(100);
    uint256 bountyTokens = total.mul(SHARE_BOUNTY).div(100);
    require (token.balanceOf(foundationAddress) == 0 && token.balanceOf(address(this)) == 0 && token.balanceOf(bountyAddress) == 0);
    token.mint(foundationAddress, foundationTokens);
    token.mint(address(this), teamTokens);
    token.mint(bountyAddress, bountyTokens);
    tokensTorelease = teamTokens.mul(25).div(100);
    token.finishMinting();

    startVesting = now;
    period1 = startVesting.add(5 minutes);
    period2 = startVesting.add(10 minutes);
    period3 = startVesting.add(15 minutes);
    period4 = startVesting.add(20 minutes);
    return true;
  }

  /**
    * @dev This is an especial owner-only function to make massive tokens minting.
    * @param _data is an array of addresses
    * @param _amount is an array of uint256
  */
  function batchMint(address[] _data,uint256[] _amount) public onlyOwner {
    for (uint i = 0; i < _data.length; i++) {
       token.mint(_data[i],_amount[i]);
    }
  }

  function pauseToken() public onlyOwner {
    token.pause();
  }

  function unpauseToken() public onlyOwner {
    token.unpause();
  }

    function TeamtokenRelease1 ()public onlyOwner {
       require(token.mintingFinished() && !distributed_round1);
    	 require (now >= period1);
       token.transfer(teamAddress,tokensTorelease);
    	 releasedTokens=tokensTorelease;
    	 distributed_round1=true;
    	}

    function TeamtokenRelease2 ()public onlyOwner {
       require(distributed_round1 && !distributed_round2);
    	 require (now >= period2);
    	 token.transfer(teamAddress,tokensTorelease);
    	 releasedTokens=releasedTokens.add(tokensTorelease);
    	 distributed_round2=true;
     }

   function TeamtokenRelease3 ()public onlyOwner {
       require(distributed_round2 && !distributed_round3);
    	 require (now >= period3);
    	 token.transfer(teamAddress,tokensTorelease);
    	 releasedTokens = releasedTokens.add(tokensTorelease);
    	 distributed_round3 = true;
     }

     function TeamtokenRelease4 ()public onlyOwner {
      require(distributed_round3 && !distributed_round4);
      require (now >= period4);
      uint256 balance = token.balanceOf(this);
      token.transfer(teamAddress,balance);
      releasedTokens = releasedTokens.add(balance);
      distributed_round4=true;
    }



}