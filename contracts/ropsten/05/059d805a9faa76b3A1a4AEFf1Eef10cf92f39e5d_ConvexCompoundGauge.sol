/**
 *Submitted for verification at Etherscan.io on 2021-10-28
*/

// File: contracts/libs/IERC20.sol



pragma solidity =0.6.12;

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

// File: contracts/libs/SafeMath.sol



pragma solidity =0.6.12;


library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
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
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// File: contracts/libs/Address.sol



pragma solidity =0.6.12;

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
        assembly {
            size := extcodesize(account)
        }
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
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data)
        internal
        view
        returns (bytes memory)
    {
        return
            functionStaticCall(
                target,
                data,
                "Address: low-level static call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
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
    function functionDelegateCall(address target, bytes memory data)
        internal
        returns (bytes memory)
    {
        return
            functionDelegateCall(
                target,
                data,
                "Address: low-level delegate call failed"
            );
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
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

// File: contracts/libs/SafeERC20.sol



pragma solidity =0.6.12;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(
            value
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            "SafeERC20: decreased allowance below zero"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(
            data,
            "SafeERC20: low-level call failed"
        );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}

// File: contracts/ConvexCompoundGauge.sol



pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;


interface IConvexBooster {
    function liquidate(
        uint256 _pid,
        int128 _coinId,
        address _user,
        uint256 _amount
    ) external returns (address, uint256);

    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) external returns (bool);

    function withdrawFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) external returns (bool);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            uint256 convexPid,
            address curveSwapAddress,
            address lpToken,
            address originCrvRewards,
            address originStash,
            address virtualBalance,
            address rewardPool,
            address stashToken,
            uint256 swapType,
            uint256 swapCoins
        );
}

interface ICompoundBooster {
    function liquidate(
        bytes32 _lendingId,
        uint256 _lendingAmount,
        uint256 _interestValue
    ) external payable returns (address);

    function poolInfo(uint256 _pid)
        external
        view
        returns (
            address lpToken,
            address rewardPool,
            address rewardLendflareTokenPool,
            address treasuryFund,
            address rewardInterestPool,
            bool isErc20,
            bool shutdown
        );

    function getLendingInfos(bytes32 _lendingId)
        external
        view
        returns (address payable, address);

    function borrow(
        uint256 _pid,
        bytes32 _lendingId,
        address _user,
        uint256 _amount,
        uint256 _collateralAmount,
        uint256 _borrowNumbers
    ) external;

    function repayBorrow(
        bytes32 _lendingId,
        address _user,
        uint256 _interestValue
    ) external payable;

    function repayBorrowErc20(
        bytes32 _lendingId,
        address _user,
        uint256 _amount,
        uint256 _interestValue
    ) external;

    function getBorrowRatePerBlock(uint256 _pid)
        external
        view
        returns (uint256);

    function getExchangeRateStored(uint256 _pid)
        external
        view
        returns (uint256);

    function getBlocksPerYears(uint256 _pid, bool isSplit)
        external
        view
        returns (uint256);

    function getUtilizationRate(uint256 _pid) external view returns (uint256);

    function getCollateralFactorMantissa(uint256 _pid)
        external
        view
        returns (uint256);
}

interface ICurveSwap {
    // function get_virtual_price() external view returns (uint256);

    // lp to token 68900637075889600000000, 2
    function calc_withdraw_one_coin(uint256 _tokenAmount, int128 _tokenId)
        external
        view
        returns (uint256);

    // token to lp params: [0,0,70173920000], false
    /* function calc_token_amount(uint256[] memory amounts, bool deposit)
        external
        view
        returns (uint256); */
}

interface ILiquidateSponsor {
    function addSponsor(bytes32 _lendingId, address _user) external payable;

    function requestSponsor(bytes32 _lendingId) external;

    function payFee(
        bytes32 _lendingId,
        address _user,
        uint256 _expendGas
    ) external;
}

contract ConvexCompoundGauge {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public convexBooster;
    address public compoundBooster;
    address public liquidateSponsor;

    uint256 public liquidateThresholdBlockNumbers;

    enum UserLendingState {
        LENDING,
        EXPIRED,
        LIQUIDATED
    }

    struct PoolInfo {
        uint256 convexPid;
        uint256[] supportPids;
        int128[] curveCoinIds;
        uint256 lendingThreshold;
        uint256 liquidateThreshold;
        uint256 borrowIndex;
    }

    struct UserLending {
        bytes32 lendingId;
        uint256 token0;
        uint256 token0Price;
        uint256 lendingAmount;
        uint256 supportPid;
        int128 curveCoinId;
        uint256 interestValue;
        uint256 borrowNumbers;
        uint256 borrowBlocksLimit;
    }

    struct LendingInfo {
        address user;
        uint256 pid;
        uint256 userLendingId;
        uint256 borrowIndex;
        uint256 startedBlock;
        uint256 utilizationRate;
        uint256 compoundRatePerBlock;
        UserLendingState state;
    }

    struct BorrowInfo {
        uint256 borrowAmount;
        uint256 supplyAmount;
    }

    struct Statistic {
        uint256 totalCollateral;
        uint256 totalBorrow;
        uint256 recentRepayAt;
    }

    struct LendingParams {
        uint256 lendingAmount;
        uint256 collateralAmount;
        uint256 interestAmount;
        uint256 borrowRate;
        uint256 utilizationRate;
        uint256 compoundRatePerBlock;
        address lpToken;
        uint256 token0Price;
    }

    PoolInfo[] public poolInfo;

    // user address => container
    mapping(address => UserLending[]) public userLendings;
    // lending id => user address
    mapping(bytes32 => LendingInfo) public lendings;
    // pool id => (borrowIndex => user lendingId)
    mapping(uint256 => mapping(uint256 => bytes32)) public poolLending;
    mapping(bytes32 => BorrowInfo) public borrowInfos;
    mapping(bytes32 => Statistic) public myStatistics;
    // number => block numbers
    mapping(uint256 => uint256) public borrowNumberLimit;

    event Borrow(
        bytes32 indexed lendingId,
        address user,
        uint256 token0,
        uint256 token0Price,
        uint256 lendingAmount,
        uint256 borrowBlocksLimit,
        UserLendingState state
    );

    event RepayBorrow(
        bytes32 indexed lendingId,
        address user,
        UserLendingState state
    );

    event Liquidate(
        bytes32 indexed lendingId,
        address user,
        uint256 liquidateAmount,
        uint256 gasSpent,
        UserLendingState state
    );

    function init(
        address _liquidateSponsor,
        address _convexBooster,
        address _compoundBooster
    ) public {
        liquidateSponsor = _liquidateSponsor;
        convexBooster = _convexBooster;
        compoundBooster = _compoundBooster;

        borrowNumberLimit[6] = 64;
        borrowNumberLimit[19] = 524288;
        borrowNumberLimit[20] = 1048576;
        borrowNumberLimit[21] = 2097152;

        liquidateThresholdBlockNumbers = 20;
    }

    function borrow(
        uint256 _pid,
        uint256 _token0,
        uint256 _borrowNumber,
        uint256 _supportPid
    ) public payable {
        require(borrowNumberLimit[_borrowNumber] != 0, "!borrowNumberLimit");
        require(msg.value == 0.1 ether, "!liquidateSponsor");

        _borrow(_pid, _supportPid, _borrowNumber, _token0);
    }

    function _getCurveInfo(
        uint256 _convexPid,
        int128 _curveCoinId,
        uint256 _token0
    ) internal view returns (address lpToken, uint256 token0Price) {
        address curveSwapAddress;
        (, curveSwapAddress, lpToken, , , , , , , ) = IConvexBooster(
            convexBooster
        ).poolInfo(_convexPid);
        token0Price = ICurveSwap(curveSwapAddress).calc_withdraw_one_coin(
            _token0,
            _curveCoinId
        );
    }

    function _borrow(
        uint256 _pid,
        uint256 _supportPid,
        uint256 _borrowNumber,
        uint256 _token0
    ) internal returns (LendingParams memory) {
        PoolInfo storage pool = poolInfo[_pid];

        pool.borrowIndex++;

        bytes32 lendingId = generateId(
            msg.sender,
            _pid,
            pool.borrowIndex + block.number
        );

        LendingParams memory lendingParams = getLendingInfo(
            _token0,
            pool.convexPid,
            pool.curveCoinIds[_supportPid],
            pool.supportPids[_supportPid],
            pool.lendingThreshold,
            pool.liquidateThreshold,
            _borrowNumber
        );

        IERC20(lendingParams.lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _token0
        );

        IERC20(lendingParams.lpToken).safeApprove(convexBooster, 0);
        IERC20(lendingParams.lpToken).safeApprove(convexBooster, _token0);

        ICompoundBooster(compoundBooster).borrow(
            pool.supportPids[_supportPid],
            lendingId,
            msg.sender,
            lendingParams.lendingAmount,
            lendingParams.collateralAmount,
            _borrowNumber
        );

        IConvexBooster(convexBooster).depositFor(
            pool.convexPid,
            _token0,
            msg.sender
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(_pid, pool.supportPids[_supportPid], address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.add(
            lendingParams.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.add(
            lendingParams.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(_pid, pool.supportPids[_supportPid], msg.sender)
        ];

        statistic.totalCollateral = statistic.totalCollateral.add(_token0);
        statistic.totalBorrow = statistic.totalBorrow.add(
            lendingParams.lendingAmount
        );

        userLendings[msg.sender].push(
            UserLending({
                lendingId: lendingId,
                token0: _token0,
                token0Price: lendingParams.token0Price,
                lendingAmount: lendingParams.lendingAmount,
                supportPid: pool.supportPids[_supportPid],
                curveCoinId: pool.curveCoinIds[_supportPid],
                interestValue: lendingParams.interestAmount,
                borrowNumbers: _borrowNumber,
                borrowBlocksLimit: borrowNumberLimit[_borrowNumber]
            })
        );

        lendings[lendingId] = LendingInfo({
            user: msg.sender,
            pid: _pid,
            borrowIndex: pool.borrowIndex,
            userLendingId: userLendings[msg.sender].length - 1,
            startedBlock: block.number,
            utilizationRate: lendingParams.utilizationRate,
            compoundRatePerBlock: lendingParams.compoundRatePerBlock,
            state: UserLendingState.LENDING
        });

        poolLending[_pid][pool.borrowIndex] = lendingId;

        ILiquidateSponsor(liquidateSponsor).addSponsor{value: msg.value}(
            lendingId,
            msg.sender
        );

        emit Borrow(
            lendingId,
            msg.sender,
            _token0,
            lendingParams.token0Price,
            lendingParams.lendingAmount,
            borrowNumberLimit[_borrowNumber],
            UserLendingState.LENDING
        );
    }

    function _repayBorrow(
        bytes32 _lendingId,
        uint256 _amount,
        bool isErc20
    ) internal {
        LendingInfo storage lendingInfo = lendings[_lendingId];
        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];
        PoolInfo memory pool = poolInfo[lendingInfo.pid];
        uint256 payAmount = userLending.lendingAmount.add(
            userLending.interestValue
        );

        uint256 maxAmount = payAmount.add(payAmount.mul(5).div(1000));

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );
        require(
            block.number <=
                lendingInfo.startedBlock.add(userLending.borrowBlocksLimit),
            "Expired"
        );

        require(
            _amount >= payAmount && _amount <= maxAmount,
            "amount range error"
        );

        lendingInfo.state = UserLendingState.EXPIRED;

        IConvexBooster(convexBooster).withdrawFor(
            pool.convexPid,
            userLending.token0,
            lendingInfo.user
        );

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );
        statistic.recentRepayAt = block.timestamp;

        if (isErc20) {
            (
                address payable proxyUser,
                address underlyToken
            ) = ICompoundBooster(compoundBooster).getLendingInfos(
                    userLending.lendingId
                );

            IERC20(underlyToken).safeTransferFrom(
                msg.sender,
                proxyUser,
                _amount
            );

            ICompoundBooster(compoundBooster).repayBorrowErc20(
                userLending.lendingId,
                lendingInfo.user,
                _amount,
                userLending.interestValue
            );
        } else {
            ICompoundBooster(compoundBooster).repayBorrow{value: _amount}(
                userLending.lendingId,
                lendingInfo.user,
                userLending.interestValue
            );
        }

        ILiquidateSponsor(liquidateSponsor).requestSponsor(
            userLending.lendingId
        );

        emit RepayBorrow(
            userLending.lendingId,
            lendingInfo.user,
            lendingInfo.state
        );
    }

    function repayBorrow(bytes32 _lendingId) public payable {
        _repayBorrow(_lendingId, msg.value, false);
    }

    function repayBorrow(bytes32 _lendingId, uint256 _amount) public {
        _repayBorrow(_lendingId, _amount, true);
    }

    function liquidate(bytes32 _lendingId) public {
        uint256 gasStart = gasleft();
        LendingInfo storage lendingInfo = lendings[_lendingId];
        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        require(
            lendingInfo.startedBlock.add(userLending.borrowNumbers).sub(
                liquidateThresholdBlockNumbers
            ) < block.number,
            "!borrowNumbers"
        );

        PoolInfo memory pool = poolInfo[lendingInfo.pid];

        lendingInfo.state = UserLendingState.LIQUIDATED;

        BorrowInfo storage borrowInfo = borrowInfos[
            getEncodePacked(lendingInfo.pid, userLending.supportPid, address(0))
        ];

        borrowInfo.borrowAmount = borrowInfo.borrowAmount.sub(
            userLending.token0Price
        );
        borrowInfo.supplyAmount = borrowInfo.supplyAmount.sub(
            userLending.lendingAmount
        );

        Statistic storage statistic = myStatistics[
            getEncodePacked(
                lendingInfo.pid,
                userLending.supportPid,
                lendingInfo.user
            )
        ];

        statistic.totalCollateral = statistic.totalCollateral.sub(
            userLending.token0
        );
        statistic.totalBorrow = statistic.totalBorrow.sub(
            userLending.lendingAmount
        );

        (address payable proxyUser, ) = ICompoundBooster(compoundBooster)
            .getLendingInfos(userLending.lendingId);

        (address underlyToken, uint256 liquidateAmount) = IConvexBooster(
            convexBooster
        ).liquidate(
                pool.convexPid,
                userLending.curveCoinId,
                lendingInfo.user,
                userLending.token0
            );

        if (underlyToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            ICompoundBooster(compoundBooster).liquidate{value: liquidateAmount}(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.interestValue
            );
        } else {
            IERC20(underlyToken).safeTransfer(proxyUser, liquidateAmount);

            ICompoundBooster(compoundBooster).liquidate(
                userLending.lendingId,
                userLending.lendingAmount,
                userLending.interestValue
            );
        }

        uint256 gasSpent = (21000 + gasStart - gasleft()).mul(tx.gasprice);

        ILiquidateSponsor(liquidateSponsor).payFee(
            userLending.lendingId,
            msg.sender,
            gasSpent
        );

        emit Liquidate(
            userLending.lendingId,
            lendingInfo.user,
            liquidateAmount,
            gasSpent,
            lendingInfo.state
        );
    }

    function setBorrowNumberLimit(uint256 _number, uint256 _blockNumbers)
        public
    {
        borrowNumberLimit[_number] = _blockNumbers;
    }

    receive() external payable {}

    function addPool(
        uint256 _convexPid,
        uint256[] memory _supportPids,
        int128[] memory _curveCoinIds,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold
    ) public {
        poolInfo.push(
            PoolInfo({
                convexPid: _convexPid,
                supportPids: _supportPids,
                curveCoinIds: _curveCoinIds,
                lendingThreshold: _lendingThreshold,
                liquidateThreshold: _liquidateThreshold,
                borrowIndex: 0
            })
        );
    }

    function setLiquidateThresholdBlockNumbers(uint256 _blockNumbers) public {
        liquidateThresholdBlockNumbers = _blockNumbers;
    }

    /* function toBytes16(uint256 x) internal pure returns (bytes16 b) {
        return bytes16(bytes32(x));
    } */

    function generateId(
        address x,
        uint256 y,
        uint256 z
    ) public pure returns (bytes32 b) {
        /* b = toBytes16(uint256(keccak256(abi.encodePacked(x, y, z)))); */
        b = keccak256(abi.encodePacked(x, y, z));
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function cursor(
        uint256 _pid,
        uint256 _offset,
        uint256 _size
    ) public view returns (bytes32[] memory, uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        uint256 size = _offset + _size > pool.borrowIndex
            ? pool.borrowIndex - _offset
            : _size;
        uint256 index;

        bytes32[] memory userLendingIds = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            bytes32 userLendingId = poolLending[_pid][_offset + i];

            userLendingIds[index] = userLendingId;
            index++;
        }

        return (userLendingIds, pool.borrowIndex);
    }

    function calculateRepayAmount(bytes32 _lendingId)
        public
        view
        returns (uint256)
    {
        LendingInfo storage lendingInfo = lendings[_lendingId];
        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        if (lendingInfo.state == UserLendingState.LIQUIDATED) return 0;

        return userLending.lendingAmount.add(userLending.interestValue);
    }

    function getPoolSupportPids(uint256 _pid)
        public
        view
        returns (uint256[] memory)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.supportPids;
    }

    function getCurveCoinId(uint256 _pid, uint256 _supportPid)
        public
        view
        returns (int128)
    {
        PoolInfo memory pool = poolInfo[_pid];

        return pool.curveCoinIds[_supportPid];
    }

    function getUserLendingState(bytes32 _lendingId)
        public
        view
        returns (UserLendingState)
    {
        LendingInfo storage lendingInfo = lendings[_lendingId];

        return lendingInfo.state;
    }

    function getLiquidateInfo(bytes32 _lendingId)
        public
        view
        returns (bool, uint256)
    {
        LendingInfo storage lendingInfo = lendings[_lendingId];
        UserLending storage userLending = userLendings[lendingInfo.user][
            lendingInfo.userLendingId
        ];

        require(
            lendingInfo.state == UserLendingState.LENDING,
            "!UserLendingState"
        );

        uint256 liquidateBlockNumbers = lendingInfo
            .startedBlock
            .add(userLending.borrowNumbers)
            .sub(liquidateThresholdBlockNumbers);

        if (liquidateBlockNumbers < block.number)
            return (true, liquidateBlockNumbers);

        return (false, liquidateBlockNumbers);
    }

    function getLendingInfo(
        uint256 _token0,
        uint256 _convexPid,
        int128 _curveId,
        uint256 _compoundPid,
        uint256 _lendingThreshold,
        uint256 _liquidateThreshold,
        uint256 _borrowBlocks
    ) public view returns (LendingParams memory) {
        (address lpToken, uint256 token0Price) = _getCurveInfo(
            _convexPid,
            _curveId,
            _token0
        );

        uint256 collateralFactorMantissa = ICompoundBooster(compoundBooster)
            .getCollateralFactorMantissa(_compoundPid);
        uint256 utilizationRate = ICompoundBooster(compoundBooster)
            .getUtilizationRate(_compoundPid);
        uint256 compoundRatePerBlock = ICompoundBooster(compoundBooster)
            .getBorrowRatePerBlock(_compoundPid);
        uint256 compoundRate = getCompoundRate(
            compoundRatePerBlock,
            _borrowBlocks
        );
        uint256 amplificationFactor = getAmplificationFactor(utilizationRate);
        uint256 lendFlareRate;

        if (utilizationRate > 0) {
            lendFlareRate = getLendFlareRate(compoundRate, amplificationFactor);
        } else {
            lendFlareRate = compoundRate.sub(1e18);
        }

        uint256 lendingAmount = (token0Price *
            1e18 *
            (1000 - _lendingThreshold - _liquidateThreshold)) /
            (1e18 + lendFlareRate) /
            1000;

        uint256 collateralAmount = lendingAmount
            .mul(compoundRate)
            .mul(1000)
            .div(800)
            .div(collateralFactorMantissa);

        uint256 interestAmount = lendingAmount.mul(lendFlareRate).div(1e18);

        return
            LendingParams({
                lendingAmount: lendingAmount,
                collateralAmount: collateralAmount,
                interestAmount: interestAmount,
                borrowRate: lendFlareRate,
                utilizationRate: utilizationRate,
                compoundRatePerBlock: compoundRatePerBlock,
                lpToken: lpToken,
                token0Price: token0Price
            });
    }

    function getUserLendingsLength(address _user)
        public
        view
        returns (uint256)
    {
        return userLendings[_user].length;
    }

    function getCompoundRate(uint256 _compoundBlockRate, uint256 n)
        public
        pure
        returns (uint256)
    {
        _compoundBlockRate = _compoundBlockRate + (10**18);

        for (uint256 i = 1; i <= n; i++) {
            _compoundBlockRate = (_compoundBlockRate**2) / (10**18);
        }

        return _compoundBlockRate;
    }

    function getAmplificationFactor(uint256 _utilizationRate)
        public
        pure
        returns (uint256)
    {
        if (_utilizationRate <= 0.9 * 1e18) {
            return uint256(10).mul(_utilizationRate).div(9).add(1e18);
        }

        return uint256(20).mul(_utilizationRate).sub(16 * 1e18);
    }

    function getLendFlareRate(
        uint256 _compoundRate,
        uint256 _amplificationFactor
    ) public pure returns (uint256) {
        return _compoundRate.sub(1e18).mul(_amplificationFactor).div(1e18);
    }

    function getEncodePacked(
        uint256 _pid,
        uint256 _supportPid,
        address _sender
    ) public pure returns (bytes32) {
        if (_sender == address(0)) {
            return generateId(_sender, _pid, _supportPid);
        }

        return generateId(_sender, _pid, _supportPid);
    }
}