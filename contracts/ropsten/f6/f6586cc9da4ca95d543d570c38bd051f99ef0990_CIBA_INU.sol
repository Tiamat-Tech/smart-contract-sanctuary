/**
 *Submitted for verification at Etherscan.io on 2021-10-30
*/

/**
This smart contract contain all transaction fee that is working perfectly with liquidty pool and swap features
If you are using remix or blockchain compiler to send tranction make sure your value has addition 18 0s, because it will be using wei value which we set it decimal to 18 except you change the decimal value to any value of your choice with must not be greater than 18.
Deployment Steps:
Process of deployment, specific the following 3addresses from the parameter (liquidity,marketing,charity). once deployed successfully. go to uniswap and send your token to the pool. the contract already given you the uniswapV2Pair address. just add the 650token with your ethereum amount you want the 650token to have. after that send airdrop your 4 recipients(which will be total at 100token meaning 25token each), and send airdrop to 3 admin addresses (which will be total of 15token meaning 5token each). after that, if you want token owner and contract address to be charged transaction fees when defined. add the address to include fee function. and anytime they make transaction both with wallet and uniswap they will be charged all the fees including the whaleTax fee.

Whale tax fee structure
Level 1 (10% -19% of the total token) = +5% = total 20%
Level 2 (20% - 39% of the total token)= +10% = total 25%
Level 3 (40% - 59% of the total token) = +20% = total 35%
Level 4 = +70% = total 45%
*/

//Uniswap router for LP and Swap
pragma solidity =0.8.0;

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

// pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

// pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
// File: Context.sol

pragma solidity ^0.8.0;

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
        return msg.data;
    }
}
// File: Ownable.sol

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
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
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
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
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal virtual {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
// File: Address.sol

pragma solidity ^0.8.0;

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash =
            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
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
        require(
            address(this).balance >= amount,
            "Address: insufficient balance"
        );

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}("");
        require(
            success,
            "Address: unable to send value, recipient may have reverted"
        );
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
    function functionCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                value,
                "Address: low-level call with value failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "Address: insufficient balance for call"
        );
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) =
            target.call{value: weiValue}(data);
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
// File: SafeMath.sol


pragma solidity ^0.8.0;

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
     * overflow (when the result is negative).EDDY
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
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
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
     *
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
     *
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
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
// File: Otium.sol

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;






interface IERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event AirdropProcessed(address recipient, uint amount, uint date);
}


contract CIBA_INU is Context, IERC20, Ownable {
    
/*
*This contain declaration of the basic variables, struct, mapping and addresses
*Some will have default value while some will be given based on the function called
*for example whalefee is not yet known. by default it is 0 but based on the amount sender is transacting its
*percentage will be calculated.
*/
  using SafeMath for uint256;
  using Address for address;

  mapping (address => uint256) private _rOwned;
  mapping (address => uint256) private _tOwned;
  mapping (address => mapping (address => uint256)) private _allowances;

  mapping (address => bool) private _isExcludedFromFee;
  mapping (address => bool) private _isExcludedFromReward;
  mapping(address => bool) public processedAirdrops;
  
  address[] private _excludedFromReward;

  address BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
  address public _liquidityAddress;
  address public _charityAddress;
  address public _marketingAddress;

  uint256 private constant MAX = ~uint256(0);
  uint256 private _tTotal = 1000000000000000 * 10**9;
  uint256 private _rTotal = (MAX - (MAX % _tTotal));
  uint256 private _tHODLrReflectsTotal;
  
  uint256 public tAirdrop = 100000000000000 *  10**9;
  uint256 public tAdminAirdrop = 15000000000000 *  10**9;

  string private _name = "Ciba Inu";
  string private _symbol = "CIBA";
  uint8 private _decimals = 9;
  
  uint256 public _reflectFee = 2;
  uint256 private _previousreflectFee = _reflectFee;
  
  uint256 public _charityFee = 3;
  uint256 private _previousCharityFee = _charityFee;
  
  uint256 public _whaleFee = 0;
  uint256 private _previousWhaleFee = _whaleFee;
  
  uint256 public _marketingFee = 8;
  uint256 private _previousMarketingFee = _marketingFee;
  
  uint256 public _liquidityFee = 2; 
  uint256 private _previousLiquidityFee = _liquidityFee;
  
  uint256 public _maxTxAmount = 1000000000000000 * 10**9;
  uint256 private _whaleTax; 

/**declaration of uniswap router address and uniwapPaired address
the uniswapVwPair will be used when our contract address has been pair with liquidity pool
*/
  IUniswapV2Router02 public immutable uniswapV2Router;
  address public immutable uniswapV2Pair;
  
/**Contructor contains some parameter of address we need to specify before deployment * then all token information and meta will be written and executed when deployed
    * some of these functions that will be executed are token supply, token burn, lp paired, etc.
    //IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);   
    // binance PANCAKE V2
    //IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);   // Ethereum mainnet, Ropsten, Rinkeby, Görli, and Kovan    
    // Create a uniswap pair for this new token//0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
       
*/
  constructor () {

    _rOwned[_msgSender()] = _rTotal;
    
    _liquidityAddress = 0x47c4fcD6cFd7f880d519780a4B1F94462CEfc80d;
    _charityAddress = 0x0473606b9b911D57ad9E6801C148bb6519e20C2f;
    _marketingAddress = 0x47c4fcD6cFd7f880d519780a4B1F94462CEfc80d;
    
    uint256 totalBurn = calculateDefaultWhaleFee(_tTotal);
    _transferBurn(owner(), totalBurn);
    

       IUniswapV2Router02 _uniswapV2Router =
       IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); 
       uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
       uniswapV2Router = _uniswapV2Router;
            
    _isExcludedFromReward[address(this)] = true;
    _isExcludedFromReward[BURN_ADDRESS] = true;
    
    _isExcludedFromFee[owner()] = true;
    _isExcludedFromFee[address(this)] = true;
    _isExcludedFromFee[BURN_ADDRESS] = true;
    _isExcludedFromFee[_charityAddress] = true;
    _isExcludedFromFee[_marketingAddress] = true;
    


    emit Transfer(address(0), _msgSender(), _tTotal);
  }

  /**FUNCTIONS: to get all information about the token they are public and can be seen or called by anybody on blockchain
  */
  
  function name() public view returns (string memory) {return _name;}
  function symbol() public view returns (string memory) {return _symbol;}
  function decimals() public view returns (uint8) {return _decimals;}
  function totalSupply() public view override returns (uint256) {return _tTotal;}
        
  function balanceOf(address account) public view override returns (uint256) {
    if (_isExcludedFromReward[account]) return _tOwned[account];
    return tokenFromReflection(_rOwned[account]);
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    _whaleFee = whaleTax(amount); 
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _whaleFee = _whaleFee + _whaleTax;
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
    return true;
  }

  function totalHODLrReflects() public view returns (uint256) {
    return _tHODLrReflectsTotal;
  }

  function totalBurned() public view returns (uint256) {
    return balanceOf(BURN_ADDRESS);
  }
  
    function totalProject() public view returns (uint256) {
    return balanceOf(_liquidityAddress);
  }
  
    function totalCharity() public view returns (uint256) {
    return balanceOf(_charityAddress);
  }
  
    function totalMarketing() public view returns (uint256) {
    return balanceOf(_marketingAddress);
  }
    
    //function to calculate whale tax
    //whaleTax and calculated by on the percentage of transfer amount to token amount 
    //i.e (transferAmount / TotalSupply) * 100
    function whaleTax(uint256 amount) public view returns (uint256) {
        
        uint256 percent = 100 * (_rTotal / amount);
        
        if(percent >= (10) && percent <= (19)){
        percent = (5 * 100);
        }
        else if(percent >= (20) && percent <= (39)){
        percent = 10;
        }
        else if(percent >= (40) && percent <= (69)){
        percent = 20;
        }
        else if(percent >= (70)){
        percent = 30;
        }
        else{
        percent = 0;
        }
        
        return percent;
    }  

  /** Airdrop claiming function
    This is occur when token owner release token to all users then selected to recieve or claim token
    the amount released by admin without any restriction until the reach maximum of airdrop specified
    you can check the total number of token to be realized before sending airdrop to anyone.
    * same thing goes to admin airdrop
  */    
  //claiming Airdrop

    function sendAirdrop(
    address recipient,
    uint amount
    ) external onlyOwner{

    uint airdropAmount = 0;
    //uint numOfRecipients = recipient.length;
    uint amountToSend = amount;// / numOfRecipients;
    require(tAirdrop > 0, 'Airdropped amount must be greater than 0');
    require(amount <= tAirdrop, 'airdropped amount must be less than than Total airdrop amount');
    //for (uint256 i = 0; i < numOfRecipients; i++) {
        require(processedAirdrops[recipient] == false, 'airdrop already processed');
        require((airdropAmount + amountToSend) <= amount, 'airdropped 100% of the tokens');
        processedAirdrops[recipient] = true;
    airdropAmount += amountToSend;
    _airDropTransfer(_msgSender(), recipient, amountToSend);
    
    emit AirdropProcessed(
      recipient,
      amountToSend,
      block.timestamp
    );
    
    tAirdrop -= airdropAmount;
  }

  //claiming Admin Airdrop

    function sendAdminAirdrop(
    address admin,
    uint amount
    ) external onlyOwner{

    uint airdropAmount = 0;
    uint amountToSend = amount;
    require(tAdminAirdrop > 0, 'Admin Airdropped amount must be greater than 0');
    require(amount <= tAdminAirdrop, 'admin airdropped amount must be less than admin Total airdrop amount');
        require(processedAirdrops[admin] == false, 'airdrop already processed');
        require((airdropAmount + amountToSend) <= amount, 'airdropped 100% of the tokens');
        processedAirdrops[admin] = true;
    
    airdropAmount += amountToSend;
    _airDropTransfer(_msgSender(), admin, amountToSend);
    
    emit AirdropProcessed(
      admin,
      amountToSend,
      block.timestamp
    );
    
    tAdminAirdrop -= airdropAmount;
  }
  //admin airdrop ends here

  //the deliver function remove the reflection transaction fee from amount send
  // and add it to holderFee variable

  function deliver(uint256 tAmount) public {
    address sender = _msgSender();
    require(!_isExcludedFromReward[sender], "Excluded addresses cannot call this function");
    (uint256 rAmount,,,,,,,,) = _getValues(tAmount);
    _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _rTotal = _rTotal.sub(rAmount);
    _tHODLrReflectsTotal = _tHODLrReflectsTotal.add(tAmount);
  }


  function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
    require(tAmount <= _tTotal, "Amount must be less than supply");
    if (!deductTransferFee) {
      (uint256 rAmount,,,,,,,,) = _getValues(tAmount);
      return rAmount;
    } else {
      (,uint256 rTransferAmount,,,,,,,) = _getValues(tAmount);
      return rTransferAmount;
    }
  }

  function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
    require(rAmount <= _rTotal, "Amount must be less than total reflections");
    uint256 currentRate =  _getRate();
    return rAmount.div(currentRate);
  }

  function isExcludedFromReward(address account) public view returns (bool) {
    return _isExcludedFromReward[account];
  }

  function excludeFromReward(address account) public onlyOwner {
    require(!_isExcludedFromReward[account], "Account is already excluded");
    if(_rOwned[account] > 0) {
      _tOwned[account] = tokenFromReflection(_rOwned[account]);
    }
    _isExcludedFromReward[account] = true;
    _excludedFromReward.push(account);
  }

  function includeInReward(address account) external onlyOwner {
    require(_isExcludedFromReward[account], "Account is already excluded");
    for (uint256 i = 0; i < _excludedFromReward.length; i++) {
      if (_excludedFromReward[i] == account) {
        _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
        _tOwned[account] = 0;
        _isExcludedFromReward[account] = false;
        _excludedFromReward.pop();
        break;
      }
    }
  }

  function excludeFromFee(address account) public onlyOwner {
    _isExcludedFromFee[account] = true;
  }
  
  function includeInFee(address account) public onlyOwner {
    _isExcludedFromFee[account] = false;
  }
  
  function setreflectFeePercent(uint256 reflectFee) external onlyOwner {
    _reflectFee = reflectFee;
  }
  
  function setWhaleFeePercent(uint256 burnFee) external onlyOwner {
    _whaleFee = burnFee;
  }
  
    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
    _liquidityFee = liquidityFee;
  }
  
    function setMarketingFeePercent(uint256 marketingFee) external onlyOwner {
    _marketingFee = marketingFee;
  }
  
    function setCharityFeePercent(uint256 charitytFee) external onlyOwner {
    _charityFee = charitytFee;
  }
  
  
  function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
    _maxTxAmount = _tTotal.mul(maxTxPercent).div(
      10**2
    );
  }

  receive() external payable {}

  function _HODLrFee(uint256 rHODLrFee, uint256 tHODLrFee) private {
    _rTotal = _rTotal.sub(rHODLrFee);
    _tHODLrReflectsTotal = _tHODLrReflectsTotal.add(tHODLrFee);
  }

  function _getValues(uint256 tAmount) 
  private view returns (
  
      uint256 rAmount, 
      uint256 rTransferAmount, 
      uint256 rReflect, 
      uint256 tTransferAmount, 
      uint256 tReflect, 
      uint256 tLiquidity, 
      uint256 tWhale, 
      uint256 tCharity,
      uint256 tMarketing
      
      ) 
  {
    ( tTransferAmount, tReflect, tLiquidity, tCharity, tWhale, tMarketing
    ) = _getTValues(tAmount, tTransferAmount, tReflect, tLiquidity, tCharity, tWhale, tMarketing);
    
    ( rAmount, rTransferAmount, rReflect, tReflect
    ) =  _getRValues(tAmount, tReflect, tLiquidity, tWhale, tCharity, tMarketing,  _getRate());
    
    return (
    rAmount, 
    rTransferAmount, 
    rReflect, 
    tTransferAmount, 
    tReflect, 
    tLiquidity,
    tWhale,
    tCharity,
    tMarketing);
  }

  //this function remove all fees from amount of token to be transfer and return their fee independently
  function _getTValues(
  uint256 tAmount, 
  uint256 tTransferAmount,
  uint256 tReflect, 
  uint256 tLiquidity, 
  uint256 tWhale, 
  uint256 tCharity,
  uint256 tMarketing
  ) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
      
    tReflect = calculatereflectFee(tAmount); 
    tLiquidity = calculateliquidityFee(tAmount);
    tWhale = calculateWhaleFee(tAmount);
    tCharity = calculateCharityFee(tAmount);
    tMarketing = calculateMarketingFee(tAmount);
    tTransferAmount = tAmount.sub(tReflect);
    tTransferAmount = tTransferAmount.sub(tWhale);
    tTransferAmount = tTransferAmount.sub(tCharity);
    tTransferAmount = tTransferAmount.sub(tLiquidity);
    tTransferAmount = tTransferAmount.sub(tMarketing);
    
    return (tTransferAmount, tReflect, tLiquidity, tCharity, tWhale, tMarketing);
  }
  
  //this function remove all fees from amount of token to be transfer and return their fee independently
  
  function _getRValues(
  uint256 tAmount, 
  uint256 tReflect, 
  uint256 tLiquidity, 
  uint256 tWhale, 
  uint256 tCharity,
  uint256 tMarketing,
  uint256 currentRate
  ) private pure returns (
      uint256 rAmount, 
      uint256 rTransferAmount, 
      uint256 rReflect, uint256) {
      
    rAmount = tAmount.mul(currentRate);
        rReflect = tReflect.mul(currentRate);
        rTransferAmount = rAmount.sub(rReflect);
    rTransferAmount = rTransferAmount.sub(tWhale.mul(currentRate));
    rTransferAmount = rTransferAmount.sub(tCharity.mul(currentRate));
    rTransferAmount = rTransferAmount.sub(tLiquidity.mul(currentRate));
    rTransferAmount = rTransferAmount.sub(tMarketing.mul(currentRate));
    
    return (rAmount, rTransferAmount, rReflect, tReflect);
  }

  //this function get the current of totalSupply and remaining of the token balance
  function _getRate() private view returns(uint256) {
    (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
    return rSupply.div(tSupply);
  }

  //this function will get token balance and subtract all transactionfee sent all some address and return the exact value 
  //for auditing purpose -tokensupply amount must alway be balance with this function
  function _getCurrentSupply() private view returns(uint256, uint256) {
    uint256 rSupply = _rTotal;
    uint256 tSupply = _tTotal;
    for (uint256 i = 0; i < _excludedFromReward.length; i++) {
      if (_rOwned[_excludedFromReward[i]] > rSupply || _tOwned[_excludedFromReward[i]] > tSupply) 
      return (_rTotal, _tTotal);
      rSupply = rSupply.sub(_rOwned[_excludedFromReward[i]]);
      tSupply = tSupply.sub(_tOwned[_excludedFromReward[i]]);
    }
    if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
    return (rSupply, tSupply);
  }
  
/**THIS SECTION CONTAINS FUNCTIONS TO CALCULATE ALL TRANSACTION ONE BY ONE INCLUDING REMOVAL OF FEES AND RESETTING OF FEES 
*/
  
  function calculatereflectFee(uint256 _amount) private view returns (uint256) {
    return _amount.mul(_reflectFee).div(
      10**2
    );
  }
  
    function calculateWhaleFee(uint256 _amount) private view returns (uint256) {
    return _amount.mul(_whaleFee).div(
      10**2
    );
  }
  
  function calculateDefaultWhaleFee(uint256 _amount) private pure returns (uint256) {
      uint256 burnP = 15;
    return _amount.mul(burnP).div(
      10**2
    );
  }
  
    function calculateCharityFee(uint256 _amount) private view returns (uint256) {
    return _amount.mul(_charityFee).div(
      10**2
    );
  }
  
    function calculateMarketingFee(uint256 _amount) private view returns (uint256) {
    return _amount.mul(_marketingFee).div(
      10**2
    );
  }
  
    function calculateliquidityFee(uint256 _amount) private view returns (uint256) {
    return _amount.mul(_liquidityFee).div(
      10**2
    );
  }
  
  function removeAllFee() private {
    if(_reflectFee == 0 && _whaleFee == 0 && _liquidityFee == 0 && _charityFee == 0 && _marketingFee == 0) return;    
    _previousreflectFee = _reflectFee;
    _previousWhaleFee = _whaleFee;
    _previousLiquidityFee = _liquidityFee;
    _previousCharityFee = _charityFee;
    _previousMarketingFee = _marketingFee;
    _reflectFee = 0;
    _whaleFee = 0;
    _liquidityFee = 0;
    _whaleTax = 0;
    _charityFee = 0;
    _marketingFee = 0;
  }
  
  function restoreAllFee() private {
    _reflectFee = _previousreflectFee;
    _whaleFee = _previousWhaleFee;
    _liquidityFee = _previousLiquidityFee;
    _charityFee = _previousCharityFee;
    _marketingFee = _previousMarketingFee;
  }
  
  //The function exclude an address from being charged
  function isExcludedFromFee(address account) public view returns(bool) {
    return _isExcludedFromFee[account];
  }

  //The function approves all transaction by the token owner address
  function _approve(address owner, address spender, uint256 amount) private {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");
    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  //this functon contain process by which any transaction is being made
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) private {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "Transfer amount must be greater than zero");
    if(from != owner() && to != owner())
      require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
    bool takeFee = true;
    if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
      takeFee = false;
    }
    _tokenTransfer(from,to,amount,takeFee);
  }
 
 //this function contain process by with airdrop is being transfer 
 function _airDropTransfer(
    address from,
    address to,
    uint256 amount
  ) private {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "Transfer amount must be greater than zero");
    if(from != owner() && to != owner())
      require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
    bool takeFee = false;
      _tokenTransfer(from,to,amount,takeFee);
   
  }
  
  // this function check all fee transaction condition in order to fire the right transaction function
  function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
    if(!takeFee)
      removeAllFee();   
    if (_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) {
      _transferFromExcluded(sender, recipient, amount);
    } else if (!_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
      _transferToExcluded(sender, recipient, amount);
    } else if (!_isExcludedFromReward[sender] && !_isExcludedFromReward[recipient]) {
      _transferStandard(sender, recipient, amount);
    } else if (_isExcludedFromReward[sender] && _isExcludedFromReward[recipient]) {
      _transferBothExcluded(sender, recipient, amount);
    } else {
      _transferStandard(sender, recipient, amount);
    }   
    if(!takeFee)
      restoreAllFee();
  }

  //The function process the whale tax to their appropriate address and report details on the blockchain
  function _transferWhale(address sender, uint256 tWhale) private {
    uint256 currentRate = _getRate();
    uint256 rWhale = tWhale.mul(currentRate);   
    _rOwned[_marketingAddress] = _rOwned[_marketingAddress].add(rWhale);
    if(_isExcludedFromReward[_marketingAddress])
      _tOwned[_marketingAddress] = _tOwned[_marketingAddress].add(tWhale);
    emit Transfer(sender, _marketingAddress, tWhale);
      
      
  }
  
  //The function burn token and report details on the blockchain
  function _transferBurn(address sender, uint256 tBurn) private {
   // uint256 currentRate = _getRate();
    //uint256 rBurn = tBurn.mul(currentRate);   
    // _rOwned[BURN_ADDRESS] = _rOwned[BURN_ADDRESS].add(rBurn);
    // if(_isExcludedFromReward[BURN_ADDRESS])
    //   _tOwned[BURN_ADDRESS] = _tOwned[BURN_ADDRESS].add(tBurn);
      
        _tTotal = _tTotal.sub(tBurn);
    _rOwned[BURN_ADDRESS] = _rOwned[BURN_ADDRESS].add(tBurn);
    _rOwned[owner()] = _rOwned[owner()].sub(tBurn);
    emit Transfer(sender, BURN_ADDRESS, tBurn);
      
      
  }
  
  //The function process the liquidity fee and send it to their appropriate address and report details on the blockchain
    function _transferLiquidity(address sender, uint256 tLiquidity) private {
    uint256 currentRate = _getRate();
    uint256 rLiquidity = tLiquidity.mul(currentRate);   
    _rOwned[_liquidityAddress] = _rOwned[_liquidityAddress].add(rLiquidity);
    if(_isExcludedFromReward[_liquidityAddress])
      _tOwned[_liquidityAddress] = _tOwned[_liquidityAddress].add(tLiquidity);
    
    emit Transfer(sender, _liquidityAddress, tLiquidity);
  }
  
  //The function process the marketing fee and send it to their appropriate address and report details on the blockchain
    function _transferMarketing(address sender, uint256 tMarketing) private {
    uint256 currentRate = _getRate();
    uint256 rMarketing = tMarketing.mul(currentRate);   
    _rOwned[_marketingAddress] = _rOwned[_marketingAddress].add(rMarketing);
    if(_isExcludedFromReward[_marketingAddress])
      _tOwned[_marketingAddress] = _tOwned[_marketingAddress].add(tMarketing);
    
    emit Transfer(sender, _marketingAddress, tMarketing);
  }
  
  //The function process the charity fee and send it to their appropriate address and report details on the blockchain
    function _transferCharity(address sender, uint256 tCharity) private {
    uint256 currentRate = _getRate();
    uint256 rCharity = tCharity.mul(currentRate);   
    _rOwned[_charityAddress] = _rOwned[_charityAddress].add(rCharity);
    if(_isExcludedFromReward[_charityAddress])
      _tOwned[_charityAddress] = _tOwned[_charityAddress].add(tCharity);
    
    emit Transfer(sender, _charityAddress, tCharity);
  }

  //The function implement function to deduct transactoin fee from the sender only and the recipient will be excluded recieve any tx fee 
  function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
    (
      uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rReflect,
      uint256 tTransferAmount,
      uint256 tReflect,
      uint256 tLiquidity,
      uint256 tWhale,
      uint256 tCharity,
      uint256 tMarketing) = _getValues(tAmount);
      
      _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
    
    _transferWhale(sender, tWhale);
        _transferLiquidity(sender, tLiquidity);
        _transferCharity(sender, tCharity);
        _transferMarketing(sender, tMarketing);
    _HODLrFee(rReflect, tReflect);
    emit Transfer(sender, recipient, tTransferAmount);
  }
  
  //The function implement function to deduct on transactoin fee from the sender only and add it to the recipient
  //giving recipient 100% amount recieved
  function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
    (
        uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rReflect,
      uint256 tTransferAmount,
      uint256 tReflect,
      uint256 tLiquidity,
      uint256 tWhale,
      uint256 tCharity,
      uint256 tMarketing) = _getValues(tAmount);
      
  _rOwned[sender] = _rOwned[sender].sub(rAmount);
    _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
    _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);  
    
    _transferWhale(sender, tWhale);
        _transferLiquidity(sender, tLiquidity);
        _transferCharity(sender, tCharity);
        _transferMarketing(sender, tMarketing);
    _HODLrFee(rReflect, tReflect);
    emit Transfer(sender, recipient, tTransferAmount);
  }
  
  //The function implement function to deduct transactoin fee from the sender and add the fee to amount recipient will recieve
  //giving recipient 100% amount recieved
  function _transferStandard(address sender, address recipient, uint256 tAmount) 
  private {
    (
          uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rReflect,
      uint256 tTransferAmount,
      uint256 tReflect,
      uint256 tLiquidity,
      uint256 tWhale,
      uint256 tCharity,
      uint256 tMarketing) = _getValues(tAmount);
      
      _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        
    _transferWhale(sender, tWhale);
        _transferLiquidity(sender, tLiquidity);
        _transferCharity(sender, tCharity);
        _transferMarketing(sender, tMarketing);
    _HODLrFee(rReflect, tReflect);
    emit Transfer(sender, recipient, tTransferAmount);
  }

  //both send and recipient are going to be paying for the fee
  //meaning fee deducted from the send will be deducted from the recipient
  function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
    (
        uint256 rAmount,
      uint256 rTransferAmount,
      uint256 rReflect,
      uint256 tTransferAmount,
      uint256 tReflect,
      uint256 tLiquidity,
      uint256 tWhale,
      uint256 tCharity,
      uint256 tMarketing) = _getValues(tAmount);
      
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);     

    _transferWhale(sender, tWhale);
        _transferLiquidity(sender, tLiquidity);
        _transferCharity(sender, tCharity);
        _transferMarketing(sender, tMarketing);
    _HODLrFee(rReflect, tReflect);
    emit Transfer(sender, recipient, tTransferAmount);
  }

}
/**
-The smart contract is generated to get more whale tax fee to manage and keep project alive.
-Update can be done on the contract as time goes on.
-Thanks.
*/