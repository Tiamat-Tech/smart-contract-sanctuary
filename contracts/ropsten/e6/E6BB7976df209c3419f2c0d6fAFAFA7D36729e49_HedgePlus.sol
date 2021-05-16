// // SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
    uint256 c = add(a,m);
    uint256 d = sub(c,1);
    return mul(div(d,m),m);
  }
}

contract HedgePlus is ERC20Detailed,Ownable{
  using SafeMath for uint256;

  // State Variables
  string constant _name = "HedgePlus";
  string constant _symbol = "HPLUS";
  uint8 public constant _decimal = 18;
  uint256 TOTAL_SUPPLY;
  uint256 public taxPercentage = 200; // 2% Tax Deduction


  // Tokenomics
  uint256 private constant PrePublicSale_Amount = 63_00_000 ether;
  uint256 private constant Platform_Amount = 42_00_000 ether;
  uint256 private constant TEAM_Amount = 21_00_000 ether;
  uint256 private constant OPERATIONS_Amount = 21_00_000 ether;
  uint256 private constant EXCHANGES_Amount = 21_00_000 ether;
  uint256 private constant MARKETING_Amount = 21_00_000 ether;
  uint256 private constant PROMOTIONS_Amount = 10_50_000 ether;
  uint256 private constant LEGAL_Amount = 10_50_000 ether;

  address private  PrePublicSale;
  address private  Platform;
  address private  TEAM;
  address private  OPERATIONS;
  address private  EXCHANGES;
  address private  MARKETING;
  address private  PROMOTIONS;
  address private  LEGAL;

  address private MarketMakingWallet; 

  // Mappings in the Contracts
  mapping (address => uint256) private _balances;
  mapping(address => bool) public isBlackListed;
  mapping (address => mapping (address => uint256)) private _allowances;

 constructor(
    address _prePublic,
    address _platform,
    address _team,
    address _marketMakingAddress
    ) public ERC20Detailed(_name,_symbol,_decimal){
   
    TOTAL_SUPPLY = 21_000_000 ether;


    PrePublicSale = _prePublic;
    Platform = _platform;
    TEAM = _team;
    MarketMakingWallet = _marketMakingAddress;
    
    _mint(owner(),100000 ether);
    _mint(_prePublic,PrePublicSale_Amount);
    _mint(_platform,Platform_Amount);
    _mint(_team,TEAM_Amount);
  }

  function totalSupply() public view returns (uint256) {
    return TOTAL_SUPPLY;
  }

  function balanceOf(address owner) public view returns (uint256) {
    return _balances[owner];
  }

  function allowance(address owner, address spender) public view returns (uint256) {
    return _allowances[owner][spender];
  }

  /**
    * @notice - Mints new tokens equal to Total Supply.
    * @dev    - Only called once in the constructor.
    * @param account owner's address
    * @param amount Total Tokens to be minted
    */
  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "Error MSG_1: Invalid Address Passed");

    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

    function changeMarketMakingAddress(address _marketMakingAddress) external onlyOwner returns(bool){
      require (_marketMakingAddress != address(0),"Error MSG_1: Invalid Address Passed");
      MarketMakingWallet = _marketMakingAddress;
      return true;
  }

 
   /**
    * @notice - External Functions for BlackListing specific addresses 
    * @dev    - Only Acceble by the Owner of the contract
    * @param _userAddresses array of addresses of the Users
    * @return - true if Function executes successfully
    */
    function blackListAddress(address[] calldata _userAddresses) external onlyOwner returns(bool){
      _addBlackList(_userAddresses);
    }
    
  /**
    * @notice - External Functions for Removing BlackListed TAG from addresses  
    * @dev    - Only Acceble by the Owner of the contract
    * @param _userAddresses array of addresses of the Users
    * @return - true if Function executes successfully
    */
    function whiteList(address[] calldata _userAddresses) external onlyOwner returns(bool){
      _removeFromBlackList(_userAddresses);
    }



   /**
    * @notice - Internal Functions for BlackListing specific addresses 
    * @param _userAddresses array of addresses of the Users
    * @return - true if Function executes successfully
    */
    function _addBlackList(address[] memory _userAddresses) internal returns(bool){
      uint256 total_addresses = _userAddresses.length;
      for(uint256 i=0;i<total_addresses;i++){
        require (!isBlackListed[_userAddresses[i]],"Error MSG_2: User Address is Already BlackListed");
        isBlackListed[_userAddresses[i]] = true;
      }
      return true;
    }

     /**
    * @notice - Internal Functions for Removing BlackListed TAG from addresses 
    * @param _userAddresses array of addresses of the Users
    * @return - true if Function executes successfully
    */
    function _removeFromBlackList(address[] memory _userAddresses) internal returns(bool){
      uint256 total_addresses = _userAddresses.length;
      for(uint256 i=0;i<total_addresses;i++){
        require (isBlackListed[_userAddresses[i]],"Error MSG_2: User Address is NOT Blacklisted");
        isBlackListed[_userAddresses[i]] = false;
      }
      return true;
    }
  /**
    * @notice - Calculates the Tax Amount to be deducted based on the Args passed and Base Percent
    * @param _amount -amount of tokens on which the tax is to be calculated    
    */
    function calculateTaxAmount(uint256 _amount) internal view returns(uint256){
      uint256 roundValue = _amount.ceil(taxPercentage);
      uint256 taxAmount = roundValue.mul(taxPercentage).div(10000);
    return taxAmount;
    }
    
  /**
    * @notice - Transfers tokens to reciever and includes tax deduction mechanism
    * @param _recipient -reciever of tokens.
    * @param _amount -amount of tokens to be transferred.
    * @return bool - TRUE if executes successfully 
    */
    function transfer(address _recipient, uint256 _amount) public returns(bool) {
    require (!isBlackListed[msg.sender] && !isBlackListed[_recipient] ,"Error MSG_2: Either Sender or Recipient is Blacklisted");
    require (_amount > 0,"Error MSG_4:Amount Cannot be ZERO");
    require(balanceOf(msg.sender) >= _amount,"ERROR MSG_3: InSufficient Balance of Sender");

    uint256 taxAmount = calculateTaxAmount(_amount);
    uint256 transferrableTokens = _amount.sub(taxAmount);
    uint256 tokensToBurn = taxAmount.div(2);

    console.log("Sender balance is %s tokens Before", _balances[msg.sender]);
    console.log("Recipient balance is %s tokens Before", _balances[_recipient]);
    console.log("Market Making balance is %s tokens Before", _balances[MarketMakingWallet]);


    _balances[msg.sender] = _balances[msg.sender].sub(_amount);
    _balances[_recipient] = _balances[_recipient].add(transferrableTokens);

     console.log("Sender balance is %s tokens After", _balances[msg.sender]);
    console.log("Recipient balance is %s tokens After", _balances[_recipient]);
    
    //HALF of Tax Amount is sent to Market Making Wallet.
    require(MarketMakingWallet != address(0),"Error MSG:Market Making Wallet is INVALID ADDRESS");
    _balances[MarketMakingWallet] = _balances[MarketMakingWallet].add(tokensToBurn);
    // HAlF of Tax amount of tokens being burnt
    TOTAL_SUPPLY = TOTAL_SUPPLY.sub(tokensToBurn);

    console.log("Market Making balance is %s tokens After", _balances[MarketMakingWallet]);
    console.log("Total Tokens Burnt is - %s",tokensToBurn);


    emit Transfer(msg.sender, _recipient, transferrableTokens);
    emit Transfer(msg.sender, address(0), tokensToBurn);
    return true;
  }
  /**
    * @notice - Transfers tokens to reciever and includes tax deduction mechanism
    * @param _sender -sender of tokens
    * @param _recipient -reciever of tokens.
    * @param _amount -amount of tokens to be transferred.
    * @return bool - TRUE if executes successfully 
    */
  function transferFrom(address _sender,address _recipient,uint256 _amount) public returns(bool res){
    require(_recipient != address(0), "Error MSG_1: Invalid Recipient Address Passed");
    require (!isBlackListed[msg.sender] && !isBlackListed[_recipient],"Error MSG_2: Either Sender or Recipient is Blacklisted");
    require (_amount > 0,"Error MSG_4:Amount Cannot be ZERO");
    require(balanceOf(_sender) >= _amount,"ERROR MSG_3: InSufficient Balance of Sender");
    require(_allowances[_sender][msg.sender] >= _amount,"ERROR MSG_4: InSufficient Allowance of Sender");

    uint256 taxAmount = calculateTaxAmount(_amount);
    uint256 transferrableTokens = _amount.sub(taxAmount);
    uint256 tokensToBurn = taxAmount.div(2);

    _balances[_sender] = _balances[_sender].sub(_amount);
    _balances[_recipient] = _balances[_recipient].add(transferrableTokens);
    
    //HALF of Tax Amount is sent to Market Making Wallet.
       require(MarketMakingWallet != address(0),"Error MSG:Market Making Wallet is INVALID ADDRESS");
    _balances[MarketMakingWallet] = _balances[MarketMakingWallet].add(tokensToBurn);
    // Tax amount of tokens being burnt
    TOTAL_SUPPLY = TOTAL_SUPPLY.sub(tokensToBurn);

    // Allowance Mapping is being Updated
    _allowances[_sender][msg.sender] = _allowances[_sender][msg.sender].sub(_amount);
    
    // Emission of EVents
    emit Transfer(_sender, _recipient, transferrableTokens);
    emit Transfer(_sender, address(0), tokensToBurn);
    return true;
  }

    /**
    * @notice - Approves Spender with specific amount of tokens to be used on owner's behalf
    * @param _spender -address that is approved to use tokens
    * @param _amount -amount of tokens to be approved.
    * @return bool - TRUE if executes successfully 
    */
  function approve(address _spender, uint256 _amount) public returns(bool) {
    require(_spender != address(0), "Error MSG_1: Invalid Spender Address Passed");
    require (!isBlackListed[msg.sender] && !isBlackListed[_spender] ,"Error MSG_2: Either Sender or Recipient is Blacklisted");

    _allowances[msg.sender][_spender] = _amount;
    emit Approval(msg.sender, _spender, _amount);
    return true;
  }
  
  /**
    * @notice - Increases the Approved amount for the spender
    * @param _spender -address that is approved to use tokens
    * @param _amount -amount of tokens to be approved.
    * @return bool - TRUE if executes successfully 
    */
  function increaseAllowance(address _spender, uint256 _amount) public returns (bool) {
      require(_spender != address(0), "Error MSG_1: Invalid Spender Address Passed");
      _allowances[msg.sender][_spender] += _amount;
      emit Approval(msg.sender, _spender,_allowances[msg.sender][_spender]);
      return true;
    }

  /**
    * @notice - Decreases the Approved amount for the spender
    * @param _spender -address that is approved to use tokens
    * @param _amount -amount of tokens to be approved.
    * @return bool - TRUE if executes successfully 
    */
  function decreaseAllowance(address _spender, uint256 _amount) public returns (bool) {
    require(_spender != address(0), "Error MSG_1: Invalid Spender Address Passed");
    _allowances[msg.sender][_spender] = _allowances[msg.sender][_spender].sub(_amount);
    emit Approval(msg.sender, _spender,_allowances[msg.sender][_spender]);
    return true;
  }


    /**
    * @notice - Burns specifc amount of tokens from the caller address
    * @param _amount  the amount of token to be burnt
    * @return bool - TRUE if executes successfully 
    */
  function burnTokens(uint256 _amount) external{
    require (!isBlackListed[msg.sender],"Error MSG_2:User is Blacklisted");

    _burnTokens(msg.sender,_amount);    
  }


    /**
    * @notice -Allows a user to Burn tokens as per his allowances
    * @param _spender the address that is approved to use/burn the tokens
    * @param _amount  the amount of token to be burnt
    * @return bool - TRUE if executes successfully 
    */
  function  _burnTokensFrom(address _spender,uint256 _amount) external{
    require(_allowances[_spender][msg.sender] >= _amount,"ERROR MSG_4: InSufficient Allowance of Sender");

    _allowances[_spender][msg.sender] = _allowances[_spender][msg.sender].sub(_amount);
    _burnTokens(_spender,_amount);
  }

    /**
    * @notice - Burns tokens from a given address
    * @param _account the address of the caller from the which the token is to be burnt
    * @param _amount  the amount of token to be burnt
    * @return bool - TRUE if executes successfully 
    */
  function  _burnTokens(address _account,uint256 _amount) internal returns(bool) {
    require(_account != address(0), "Error MSG_1: Invalid Account Address Passed");
    require (_amount > 0,"Error MSG_4:Amount Cannot be ZERO");
    require(balanceOf(_account) >= _amount,"ERROR MSG_3: InSufficient Balance of Sender");

    TOTAL_SUPPLY = TOTAL_SUPPLY.sub(_amount);
    _balances[_account] = _balances[_account].sub(_amount);
    emit Transfer(_account,address(0),_amount);

    return true;
    
  }
  
}