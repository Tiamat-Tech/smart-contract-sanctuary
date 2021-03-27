/**
 *Submitted for verification at Etherscan.io on 2021-03-27
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


abstract contract BEP20Token {

  
   //totalsupply
   function totalSupply() public view virtual returns (uint256 _totalSupply);

    /// @param _owner The address from which the balance will be retrieved
    
    function balanceOf(address _owner) public view virtual returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
   
    function transfer(address _to, uint256 _value) public virtual returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
   
    function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool success);
    function approve(address _spender, uint256 _value) public virtual returns (bool success);
    function disApprove(address _spender)  public virtual returns (bool success);
  
     /// @param owner The address of the account owning tokens
    /// @param spender The address of the account able to transfer the tokens
    
    function allowance(address owner, address spender) public view virtual returns (uint256 _allowances);
    function increaseAllowance(address _spender, uint _addedValue) public virtual returns (bool success);
    function decreaseAllowance(address _spender, uint _subtractedValue) public virtual returns (bool success);
     function name() public view virtual returns (string memory);

    /* Get the contract constant _symbol */
    function symbol() public view virtual returns (string memory);

    /* Get the contract constant _decimals */
    function decimals() public view virtual returns (uint8 _decimals); 

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    
}


/**
 * @title SafeBEP20
 * @dev Wrappers around BEP20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeBEP20 for IBEP20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeBEP20 {
    using Address for address;

    function safeTransfer(BEP20Token token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(BEP20Token token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IBEP20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(BEP20Token token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeBEP20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(BEP20Token token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(BEP20Token token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeBEP20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
        
  
    }
    

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(BEP20Token token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeBEP20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeBEP20: BEP20 operation did not succeed");
        }
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 */
abstract contract ReentrancyGuarded {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/**
  * TokenBurner Contract is a selfDestructive contract where the swapped tokens are sent for burning and the contract destroy itself
  * 
  *
**/ 
contract TokenBurner is ReentrancyGuarded{
    
    BEP20Token private token;
    uint256 private amountToBeBurned;
    constructor(
        BEP20Token _tokenaddress,
        uint256 _amount
        )
        {
            token = _tokenaddress;
            amountToBeBurned = _amount;
        }
    function letBurn() public nonReentrant
    {
        _destroy();
    }
    
    function _destroy() internal {
        selfdestruct(payable(address(this)));
    }
}


/*
Unique Token Pool contract with ETH vault for swap 
*/
contract FXPTokenSwapPoolContract is ReentrancyGuarded, Ownable {
    
    using SafeBEP20 for BEP20Token; //SafeBEP20 library used for safe transfer of tokens
    event Received(address,uint256); // Ether received event triggered when ether is added to this vault
    event SwapRateChangedTo(uint256); 
    event Swapped(address,uint256); // Swapped event triggered once tokens are swapped
    
   
     BEP20Token public tokenContractAddress; // The unique token contract address of the token pool
     uint256 public FXPInVaultLimit; // the ether limit of the vault in wei which is changed when swapped or more ethers are added
     string public poolName; //The name of the token is set as the name of the Pool
     uint256 public poolTokenSupply; // Token Supply of this token Pool
      bool private swapRequestStatus; // 'true' value means a swap request is in progress
     BEP20Token public poolBaseCurrencyFXP;
    constructor(
    BEP20Token _tokenaddress, // takes the token address as parameter
    uint256 _FXP_su_in_vault,      // inittialize with ether limit at beiginning in FXP . su stands for smallest unit
    BEP20Token _baseCurrencyFXP
  )
    
  {
    
    tokenContractAddress = _tokenaddress; // initialize with token address
    FXPInVaultLimit = _FXP_su_in_vault ;  // inittialize with ether limit ata beiginning which needed to deposited
    poolName = tokenContractAddress.name(); //pool name
    poolTokenSupply = tokenContractAddress.totalSupply(); // initialize with the token's totalsupplys
    swapRequestStatus = false;
    poolBaseCurrencyFXP = _baseCurrencyFXP;
    
  }

  //modifier to check whether pool is active or not
   modifier swapNotOnProgress(){
        require(!swapRequestStatus, "A swap request is in progress");
        _;
        
    }    
    
/*
 returns swap rate of 1 token in wei
*/
function swapRate() public view returns(uint256 _ramount)
{
    require(poolBaseCurrencyFXP.balanceOf(address(this)) >= FXPInVaultLimit,"Full initial proposed amount of FXP not deposited yet");
    require(poolTokenSupply != 0, "Token supply is 0");
    return uint256((poolBaseCurrencyFXP.balanceOf(address(this)) * (10 ** uint256(tokenContractAddress.decimals()))) / poolTokenSupply); // swap rate of 1 Token in smallest FXP unit
}

/*_requestor parameter takes the address of the user who sent swap request
 * _amount parameter takes the exact amount of tokens to be swapped (not the smallest unit)

*/
function requestSwap(address  _requestor, uint256 _amount) public nonReentrant onlyOwner
{
    require(poolBaseCurrencyFXP.balanceOf(address(this)) >= FXPInVaultLimit,"Full initial proposed amount of FXP not deposited yet");
    require(poolTokenSupply != 0, "Token supply is 0");
    require(_requestor != address(0));
    require(tokenContractAddress.balanceOf(address(this)) >= (_amount * (10 ** uint256(tokenContractAddress.decimals()))));
    FXPInVaultLimit = poolBaseCurrencyFXP.balanceOf(address(this));
    
    swapRequestStatus = true;
    // calculate sufxp ( FXP smallest Unit)  amount according to currenct swap rate
    uint256 swapedsufxpamount = _amount * swapRate();
    
    //smallesttoken units
    uint256 smallestTokenUnits = _amount * (10 ** uint256(tokenContractAddress.decimals()));
    
    //update pools FXP balance limit
    FXPInVaultLimit = poolBaseCurrencyFXP.balanceOf(address(this)) - swapedsufxpamount;
    
    //burn the amount of tokens from requestors tokenbalance, deduct the supply first before transferring the tokens to burner to avoid redundancy
    poolTokenSupply -= smallestTokenUnits;
    
    //create tokenburner contract for current swapable amount of tokens
    
    TokenBurner lit = new TokenBurner(tokenContractAddress, smallestTokenUnits); //create burner contract for the swapped amount of tokens
    SafeBEP20.safeTransfer(tokenContractAddress,address(lit), smallestTokenUnits); // transfer the swapped tokens to the burner
    lit.letBurn(); // Burn 
    
    
    //send FXP as per the swap rate 
    SafeBEP20.safeTransfer(poolBaseCurrencyFXP, _requestor,swapedsufxpamount);
    swapRequestStatus = false;
    emit Swapped(_requestor, _amount);
}

//function for withdrawal of accidentally deposited tokens to this pool, only the factory contract can call
    function _withdrawTokenFromContract(BEP20Token _token, uint256 _tamount) public nonReentrant swapNotOnProgress onlyOwner{
        require(_token != poolBaseCurrencyFXP, "FXP withdrawal from Pools not allowed");
        SafeBEP20.safeTransfer(_token,msg.sender, _tamount);
    }
}
/*
The factory contract to create Token Pools for swapping with ETH
*/
contract FXPTokenPairFactory is Ownable, ReentrancyGuarded{
    
    using SafeBEP20 for BEP20Token;
    
    //pooldetails storing the details of a created tokenpool 
    struct PoolDetails{
        string poolName;
        address poolCreator;
        FXPTokenSwapPoolContract tokenPool; 
        uint256 totalGrantedEthAmount;
        BEP20Token tokenAddress;
        bool exist;
        }
    mapping (address => PoolDetails) public PoolsRecords; //map of addresses referencing to pooldetails record
    address[] public tokenPools; // array of addresses which are essentially the keys of the mapping above
    uint32 public numOfPools = 0 ; //initialize numOfPools with 0
    BEP20Token public  FXPToken = BEP20Token(0xe4719958B01BeCFf8A22d5f4353E7F57a989F85D); //FXPToken is what, user will get after swapping 
    event TokenPoolCreated(FXPTokenSwapPoolContract);
    
    //create the token pool contract
function createTokenPoolContract(BEP20Token _tokenaddr, uint256 FXPInPool) private returns(FXPTokenSwapPoolContract)
{
    require(_tokenaddr != FXPToken);
    uint256 smallestUnitFXPInpool = FXPInPool * (10 ** FXPToken.decimals());
    FXPTokenSwapPoolContract swapContract = new FXPTokenSwapPoolContract(_tokenaddr,smallestUnitFXPInpool,FXPToken);
    return swapContract;
}

//call pool contract create function and put record
function buildTokenPool(BEP20Token _tokenaddr, uint256 FXPInPool) public nonReentrant
{
    require(!PoolsRecords[address(_tokenaddr)].exist, "The token pool already exists");
   FXPTokenSwapPoolContract swapContractAddress =  createTokenPoolContract(_tokenaddr,FXPInPool);
   PoolsRecords[address(_tokenaddr)] = PoolDetails({
                                                poolName: _tokenaddr.name(),
                                                poolCreator: msg.sender,
                                                tokenPool: swapContractAddress,
                                                totalGrantedEthAmount: FXPInPool,
                                                tokenAddress: _tokenaddr,
                                                exist: true
                                            });
                                            numOfPools += 1;
    tokenPools.push(address(_tokenaddr));                                        
    emit TokenPoolCreated(swapContractAddress);          
}

//get the token pool swap rate
function getTokenSwapRate(BEP20Token _tokenaddr) external view returns(uint256 _swaprate)
{
     require(PoolsRecords[address(_tokenaddr)].exist, "The token pool does not exist");
     return PoolsRecords[address(_tokenaddr)].tokenPool.swapRate();
}
/**** IMPORTANT : Before calling this function the user needs to appove the swapable amount to be spent by the factory address, ****
 ***if factory contract address is not added as allowance of the token contract swap will not take place and function will revert ***/
//swap token 
function swapToken(BEP20Token _tokenaddr, uint256 _amount) public nonReentrant 
{
    require(PoolsRecords[address(_tokenaddr)].exist, "The token pool does not exist");
    require(_tokenaddr.allowance(msg.sender,address(this)) >= _amount);
    uint256 smallestTokenUnits = _amount * (10 ** uint256(_tokenaddr.decimals()));
    
    //transfer the tokens to the pool which will be burnt after swapping
    SafeBEP20.safeTransferFrom(_tokenaddr, msg.sender, address(PoolsRecords[address(_tokenaddr)].tokenPool),smallestTokenUnits);
    
    //swap request to token pool
    PoolsRecords[address(_tokenaddr)].tokenPool.requestSwap(msg.sender, _amount);
}

//function for withdrawal of accidentally deposited tokens to factory, only the factory contract owner can call
    function withdrawTokenFromcontract(BEP20Token _token, uint256 _tamount) public onlyOwner{
        require(_token.balanceOf(address(this)) >= _tamount);
        SafeBEP20.safeTransfer(_token,msg.sender, _tamount);
    }
    
//function for withdrawal of accidentally deposited tokens ( other than FXP ) to any pool
    function withdrawTokenFromPoolContract(BEP20Token _token, FXPTokenSwapPoolContract _pool, uint256 _tamount) public onlyOwner{
        require(_token != FXPToken, "You can not withdraw FXP from any POOL");
        //uint256 blnc = FXPToken.balanceOf(address(this));
        _pool._withdrawTokenFromContract(_token,_tamount);
    }    
}