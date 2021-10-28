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

// File: contracts/convex/ConvexInterfaces.sol



pragma solidity =0.6.12;

interface IConvexBooster {
    function deposit( uint256 _pid, uint256 _amount, bool _stake ) external returns (bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
    function cliamStashToken( address _token, address _rewardAddress, address _lfRewardAddress, uint256 _rewards ) external;

    /* 
    struct PoolInfo {
        address lptoken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }
     */
    function poolInfo(uint256) external view returns(address,address,address,address,address, bool);
    function isShutdown() external view returns(bool);
    function minter() external view returns(address);
    function earmarkRewards(uint256) external returns(bool);
}

interface IConvexStaker {
    function deposit( address _sender, uint256 _pid, address _lpToken, uint256 _amount,address _rewardPool ) external;
    function withdraw( address _sender, uint256 _pid, address _lpToken, uint256 _amount,address _rewardPool ) external;
    function liquidate( address _liquidater, address _liquidateSender, uint256 _pid, address _lpToken, uint256 _amount, address _rewardPool ) external;
    function earmarkRewards(uint256,address _rewardPool) external returns(bool);
    function poolInfo(uint256) external view returns(address,address,address,address,address, bool);
}

interface IConvexRewardPool {
    function stake(address _for, uint256 amount) external;
    function stakeFor(address _for, uint256 amount) external;
    function withdraw(address _for, uint256 amount) external;
    function withdrawFor(address _for, uint256 amount) external;
    function queueNewRewards(uint256 _rewards) external;
    function rewardToken() external returns(address);
    function rewardConvexToken() external returns(address);

    function getReward(address _account) external returns (bool);
    function getReward(address _account, bool _claimExtras) external returns (bool);
    function earned(address account) external view returns (uint256);

    function extraRewards(uint256 _idx) external view returns (address);
    function extraRewardsLength() external view returns (uint256);
    function addExtraReward(address _reward) external returns(bool);

    function withdrawAndUnwrap(uint256 amount, bool claim) external returns(bool);
    /* 
    function clearExtraRewards() external; */
}

interface IConvexRewardFactory {
    function CreateRewards(address _reward, address _virtualBalance, address _operator) external returns (address);
}

interface ICurveSwap {
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
    function remove_liquidity(uint256 _token_amount, uint256[] memory min_amounts) external;
    function coins(uint256 _coinId) external view returns(address);
    function balances(uint256 _coinId) external view returns(uint256);
}

interface IConvexStashRewardPool {
    function earned(address account) external view returns (uint256);
    function getReward() external;
    function getReward(address _account) external;
    function donate(uint256 _amount) external payable returns (bool);
    function queueNewRewards(uint256 _rewards) external;
}

// File: contracts/common/IVirtualBalanceWrapper.sol



pragma solidity =0.6.12;

interface IVirtualBalanceWrapperFactory {
    function CreateVirtualBalanceWrapper(address op) external returns (address);
}

interface IVirtualBalanceWrapper {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function stakeFor(address _for, uint256 _amount) external returns (bool);

    function withdrawFor(address _for, uint256 amount) external returns (bool);
}

// File: contracts/libs/Math.sol



pragma solidity =0.6.12;

library Math {
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + (((a % 2) + (b % 2)) / 2);
    }
}

// File: contracts/convex/ConvexStashRewardPool.sol



pragma solidity =0.6.12;






contract ConvexStashRewardPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    uint256 public constant duration = 7 days;

    address public operator;
    address public virtualBalance;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public queuedRewards = 0;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    uint256 public newRewardRatio = 830;
    // uint256 private _totalSupply;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    // mapping(address => uint256) private _balances;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _reward,
        address _op,
        address _virtualBalance
    ) public {
        rewardToken = IERC20(_reward);
        operator = _op;
        virtualBalance = _virtualBalance;
    }

    // function totalSupply() public view returns (uint256) {
    //     return _totalSupply;
    // }

    // function balanceOf(address _for) public view returns (uint256) {
    //     return _balances[_for];
    // }

    modifier updateReward(address _for) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_for != address(0)) {
            rewards[_for] = earned(_for);
            userRewardPerTokenPaid[_for] = rewardPerTokenStored;
        }
        _;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (IVirtualBalanceWrapper(virtualBalance).totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(IVirtualBalanceWrapper(virtualBalance).totalSupply())
            );
    }

    function earned(address _for) public view returns (uint256) {
        /* return
            balanceOf(_for)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[_for]))
                .div(1e18)
                .add(rewards[_for]); */
        return
            IVirtualBalanceWrapper(virtualBalance)
                .balanceOf(_for)
                .mul(1 days)
                .div(1e18)
                .add(rewards[_for]);
    }

    function getReward(address _for) public updateReward(_for) {
        uint256 reward = earned(_for);
        if (reward > 0) {
            rewards[_for] = 0;
            rewardToken.safeTransfer(_for, reward);

            emit RewardPaid(_for, reward);
        }
    }

    function getReward() external {
        getReward(msg.sender);
    }

    function donate(uint256 _amount) external returns (bool) {
        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        queuedRewards = queuedRewards.add(_amount);
    }

    function queueNewRewards(uint256 _rewards) external {
        require(msg.sender == operator, "!authorized");

        _rewards = _rewards.add(queuedRewards);

        if (block.timestamp >= periodFinish) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
            return;
        }

        //et = now - (finish-duration)
        uint256 elapsedTime = block.timestamp.sub(periodFinish.sub(duration));
        //current at now: rewardRate * elapsedTime
        uint256 currentAtNow = rewardRate * elapsedTime;
        uint256 queuedRatio = currentAtNow.mul(1000).div(_rewards);
        if (queuedRatio < newRewardRatio) {
            notifyRewardAmount(_rewards);
            queuedRewards = 0;
        } else {
            queuedRewards = _rewards;
        }
    }

    function notifyRewardAmount(uint256 _reward)
        internal
        updateReward(address(0))
    {
        historicalRewards = historicalRewards.add(_reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = _reward.div(duration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);

            _reward = _reward.add(leftover);
            rewardRate = _reward.div(duration);
        }

        currentRewards = _reward;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(duration);

        emit RewardAdded(_reward);
    }
}

// File: contracts/convex/ConvexStashTokens.sol



pragma solidity =0.6.12;







interface IConvexExtraRewardStash {
    function tokenCount() external view returns (uint256);

    function tokenInfo(uint256 _idx)
        external
        view
        returns (
            address token,
            address rewardAddress,
            uint256 lastActiveTime
        );
}

/* interface IConvexStashRewardPool {
    function earned(address account) external view returns (uint256);

    function getReward() external;

    function getReward(address _account) external;
}

interface IConvexBooster {
    function cliamStashToken(
        address _token,
        address _rewardAddress,
        address _lfRewardAddress,
        uint256 _rewards
    ) external;
} */

contract ConvexStashTokens {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public convexStash;
    uint256 public pid;
    address public operator;
    address public virtualBalance;

    struct TokenInfo {
        address token;
        address originRewardAddress;
        uint256 originLastActiveTime;
        address rewardAddress;
    }

    // uint256 public tokenCount;
    // TokenInfo[] public tokenInfo;
    mapping(address => TokenInfo) tokenInfos;

    constructor(
        address _operator,
        address _virtualBalance,
        uint256 _pid,
        address _convexStash
    ) public {
        operator = _operator;
        virtualBalance = _virtualBalance;
        pid = _pid;
        convexStash = _convexStash;
    }

    function sync() public {
        require(msg.sender == operator, "!authorized");

        uint256 length = IConvexExtraRewardStash(convexStash).tokenCount();

        if (length > 0) {
            for (uint256 i = 0; i < length; i++) {
                (
                    address token,
                    address rewardAddress,
                    uint256 lastActiveTime
                ) = IConvexExtraRewardStash(convexStash).tokenInfo(i);

                if (token == address(0)) continue;

                TokenInfo storage tokenInfo = tokenInfos[token];

                if (tokenInfo.token == address(0)) {
                    tokenInfo.token = token;
                    tokenInfo.originRewardAddress = rewardAddress;
                    tokenInfo.originLastActiveTime = lastActiveTime;
                    tokenInfo.rewardAddress = address(
                        new ConvexStashRewardPool(
                            token,
                            operator,
                            virtualBalance
                        )
                    );
                }
            }
        }
    }

    function stashRewards() external returns (bool) {
        require(msg.sender == operator, "!authorized");

        uint256 length = IConvexExtraRewardStash(convexStash).tokenCount();

        if (length > 0) {
            for (uint256 i = 0; i < length; i++) {
                (
                    address token,
                    address rewardAddress,

                ) = IConvexExtraRewardStash(convexStash).tokenInfo(i);

                if (token == address(0)) continue;

                uint256 rewards = IConvexStashRewardPool(rewardAddress).earned(
                    address(this)
                );

                if (rewards > 0) {
                    IConvexBooster(operator).cliamStashToken(
                        token,
                        rewardAddress,
                        tokenInfos[token].rewardAddress,
                        rewards
                    );
                }
            }
        }
    }
}

// File: contracts/ConvexBooster.sol


pragma solidity 0.6.12;





contract ConvexBooster {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public convexRewardFactory;
    address public virtualBalanceWrapperFactory;
    address public convexBooster;
    address public rewardCrvToken;

    struct PoolInfo {
        uint256 convexPid;
        address curveSwapAddress; /* like 3pool https://github.com/curvefi/curve-js/blob/master/src/constants/abis/abis-ethereum.ts */
        address lpToken;
        address originCrvRewards;
        address originStash;
        address virtualBalance;
        address rewardPool;
        address stashToken;
        uint256 swapType;
        uint256 swapCoins;
    }

    PoolInfo[] public poolInfo;

    event Deposited(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address _convexBooster,
        address _convexRewardFactory,
        address _virtualBalanceWrapperFactory,
        address _rewardCrvToken
    ) public {
        convexRewardFactory = _convexRewardFactory;
        convexBooster = _convexBooster;
        virtualBalanceWrapperFactory = _virtualBalanceWrapperFactory;
        rewardCrvToken = _rewardCrvToken;
    }

    function addConvexPool(
        uint256 _convexPid,
        address _curveSwapAddress,
        uint256 _swapType,
        uint256 _swapCoins
    ) public {
        (
            address lpToken,
            ,
            ,
            address originCrvRewards,
            address originStash,
            bool shutdown
        ) = IConvexBooster(convexBooster).poolInfo(_convexPid);

        require(shutdown == false, "!shutdown");

        address virtualBalance = IVirtualBalanceWrapperFactory(
            virtualBalanceWrapperFactory
        ).CreateVirtualBalanceWrapper(address(this));

        address rewardPool = IConvexRewardFactory(convexRewardFactory)
            .CreateRewards(rewardCrvToken, virtualBalance, address(this));

        address stashToken;

        uint256 extraRewardsLength = IConvexRewardPool(originCrvRewards)
            .extraRewardsLength();

        // if (originStash != address(0)) {
        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address extraRewardToken = IConvexRewardPool(originCrvRewards)
                    .extraRewards(i);

                address extraRewardPool = IConvexRewardFactory(
                    convexRewardFactory
                ).CreateRewards(
                        IConvexRewardPool(extraRewardToken).rewardToken(),
                        virtualBalance,
                        address(this)
                    );

                IConvexRewardPool(rewardPool).addExtraReward(extraRewardPool);
            }
            /* ConvexStashTokens convexStashTokens = new ConvexStashTokens(
                address(this),
                virtualBalance,
                poolInfo.length,
                stash
            );

            convexStashTokens.sync();

            stashToken = address(convexStashTokens); */
        }

        poolInfo.push(
            PoolInfo({
                convexPid: _convexPid,
                curveSwapAddress: _curveSwapAddress,
                lpToken: lpToken,
                originCrvRewards: originCrvRewards,
                originStash: originStash,
                virtualBalance: virtualBalance,
                rewardPool: rewardPool,
                stashToken: stashToken,
                swapType: _swapType,
                swapCoins: _swapCoins
            })
        );
    }

    /* function deposit(uint256 _pid, uint256 _amount) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IERC20(pool.lpToken).safeTransferFrom(
            msg.sender,
            convexStaker,
            _amount
        );

        IConvexStaker(convexStaker).deposit(
            msg.sender,
            pool.targetPid,
            pool.lpToken,
            _amount,
            pool.rewardPool
        );

        emit Deposited(msg.sender, _pid, _amount);

        return true;
    } */

    function depositFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IERC20(pool.lpToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        // (
        //     address lpToken,
        //     address token,
        //     address gauge,
        //     address crvRewards,
        //     address stash,
        //     bool shutdown
        // ) = IConvexBooster(convexBooster).poolInfo(pool.convexPid);
        (, , , , , bool shutdown) = IConvexBooster(convexBooster).poolInfo(
            pool.convexPid
        );

        require(!shutdown, "!shutdown");

        uint256 balance = IERC20(pool.lpToken).balanceOf(address(this));

        if (balance > 0) {
            IERC20(pool.lpToken).safeApprove(convexBooster, 0);
            IERC20(pool.lpToken).safeApprove(convexBooster, balance);

            IConvexBooster(convexBooster).deposit(
                pool.convexPid,
                balance,
                true
            );
            // IConvexRewardPool(pool.rewardPool).stakeFor(_user, _amount);
            IVirtualBalanceWrapper(pool.virtualBalance).stakeFor(
                _user,
                _amount
            );
        }

        emit Deposited(_user, _pid, _amount);

        return true;
    }

    /* function withdraw(uint256 _pid, uint256 _amount) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        IConvexStaker(convexStaker).withdraw(
            msg.sender,
            _pid,
            pool.lpToken,
            _amount,
            pool.rewardPool
        );

        return true;
    } */
    function withdrawFor(
        uint256 _pid,
        uint256 _amount,
        address _user
    ) public returns (bool) {
        PoolInfo storage pool = poolInfo[_pid];

        // if (pool.stash != address(0)) {
        //     IConvexStash(pool.stash).stashRewards();
        // }

        // IConvexStaker(convexStaker).withdraw(
        //     _user,
        //     _pid,
        //     pool.lpToken,
        //     _amount,
        //     pool.rewardPool
        // );
        // 应该是去rewardPool中体现
        // IConvexBooster(convexBooster).withdraw(pool.convexPid, _amount);
        IConvexRewardPool(pool.originCrvRewards).withdrawAndUnwrap(
            _amount,
            true
        );
        IERC20(pool.lpToken).safeTransfer(_user, _amount);
        IVirtualBalanceWrapper(pool.virtualBalance).withdrawFor(_user, _amount);
        // IConvexRewardPool(pool.rewardPool).withdrawFor(_user, _amount);

        return true;
    }

    // function earmarkRewards(uint256 _pid) external returns (bool) {
    //     PoolInfo storage pool = poolInfo[_pid];

    //     if (pool.stashToken != address(0)) {
    //         ConvexStashTokens(pool.stashToken).stashRewards();
    //     }

    //     // if (pool.stash != address(0)) {
    //     //     //claim extra rewards
    //     //     IConvexStash(pool.stash).claimRewards();
    //     //     //process extra rewards
    //     //     IConvexStash(pool.stash).processStash();
    //     // }

    //     // IConvexStaker(convexStaker).earmarkRewards(
    //     //     pool.convexPid,
    //     //     pool.rewardPool
    //     // );

    //     // new
    //     // IConvexBooster(booster).earmarkRewards(_pid);

    //     // address crv = IConvexRewardPool(_rewardPool).rewardToken();
    //     // address cvx = IConvexRewardPool(_rewardPool).rewardConvexToken();
    //     // uint256 crvBal = IERC20(crv).balanceOf(address(this));
    //     // uint256 cvxBal = IERC20(cvx).balanceOf(address(this));

    //     // if (cvxBal > 0) {
    //     //     IERC20(cvx).safeTransfer(_rewardPool, cvxBal);
    //     // }

    //     // if (crvBal > 0) {
    //     //     IERC20(crv).safeTransfer(_rewardPool, crvBal);

    //     //     IConvexRewardPool(_rewardPool).queueNewRewards(crvBal);
    //     // }

    //     return true;
    // }

    //claim fees from curve distro contract, put in lockers' reward contract
    // function earmarkFees() external returns (bool) {
    //     // //claim fee rewards
    //     // IStaker(staker).claimFees(feeDistro, feeToken);
    //     // //send fee rewards to reward contract
    //     // uint256 _balance = IERC20(feeToken).balanceOf(address(this));
    //     // IERC20(feeToken).safeTransfer(lockFees, _balance);
    //     // IRewards(lockFees).queueNewRewards(_balance);
    //     return true;
    // }

    function liquidate(
        uint256 _pid,
        int128 _coinId,
        address _user,
        uint256 _amount
    ) external returns (address, uint256) {
        PoolInfo storage pool = poolInfo[_pid];

        IConvexBooster(convexBooster).withdraw(pool.convexPid, _amount);
        IERC20(pool.lpToken).safeTransfer(_user, _amount);
        IVirtualBalanceWrapper(pool.virtualBalance).withdrawFor(_user, _amount);
        // IConvexRewardPool(pool.rewardPool).withdrawFor(_user, _amount);

        IERC20(pool.lpToken).safeApprove(pool.curveSwapAddress, 0);
        IERC20(pool.lpToken).safeApprove(pool.curveSwapAddress, _amount);

        address underlyToken = ICurveSwap(pool.curveSwapAddress).coins(
            uint256(_coinId)
        );

        if (pool.swapType == 0) {
            ICurveSwap(pool.curveSwapAddress).remove_liquidity_one_coin(
                _amount,
                _coinId,
                0
            );
        }

        if (pool.swapType == 1) {
            uint256[] memory min_amounts = new uint256[](pool.swapCoins);

            ICurveSwap(pool.curveSwapAddress).remove_liquidity(
                _amount,
                min_amounts
            );
        }

        // eth
        if (underlyToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
            uint256 totalAmount = address(this).balance;

            msg.sender.transfer(totalAmount);

            return (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, totalAmount);
        } else {
            uint256 totalAmount = IERC20(underlyToken).balanceOf(address(this));

            IERC20(underlyToken).safeTransfer(msg.sender, totalAmount);

            return (underlyToken, totalAmount);
        }
    }

    function cliamRewardToken(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];

        address originCrvRewards = pool.originCrvRewards;
        address currentCrvRewards = pool.rewardPool;
        IConvexRewardPool(originCrvRewards).getReward(address(this), true);
        address rewardUnderlyToken = IConvexRewardPool(originCrvRewards)
            .rewardToken();
        uint256 crvBalance = IERC20(rewardUnderlyToken).balanceOf(
            address(this)
        );

        if (crvBalance > 0) {
            IERC20(rewardUnderlyToken).safeTransfer(
                currentCrvRewards,
                crvBalance
            );

            IConvexRewardPool(originCrvRewards).queueNewRewards(crvBalance);
        }

        uint256 extraRewardsLength = IConvexRewardPool(currentCrvRewards)
            .extraRewardsLength();

        if (extraRewardsLength > 0) {
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address currentExtraReward = IConvexRewardPool(
                    currentCrvRewards
                ).extraRewards(i);
                address originExtraRewardToken = IConvexRewardPool(
                    originCrvRewards
                ).extraRewards(i);
                address extraRewardUnderlyToken = IConvexRewardPool(
                    originExtraRewardToken
                ).rewardToken();

                IConvexRewardPool(originExtraRewardToken).getReward(
                    address(this)
                );

                uint256 extraBalance = IERC20(extraRewardUnderlyToken)
                    .balanceOf(address(this));

                if (extraBalance > 0) {
                    IERC20(extraRewardUnderlyToken).safeTransfer(
                        currentExtraReward,
                        extraBalance
                    );

                    IConvexRewardPool(currentExtraReward).queueNewRewards(
                        extraBalance
                    );
                }
            }
        }
    }

    function cliamAllRewardToken() public {
        for (uint256 i = 0; i < poolInfo.length; i++) {
            cliamRewardToken(i);
        }
    }

    // function cliamStashToken(
    //     address _token,
    //     address _rewardAddress,
    //     address _lfRewardAddress,
    //     uint256 _rewards
    // ) public {
    //     IConvexStashRewardPool(_rewardAddress).getReward(address(this));

    //     IERC20(_token).safeTransfer(_lfRewardAddress, _rewards);

    //     IConvexStashRewardPool(_rewardAddress).queueNewRewards(_rewards);
    // }

    receive() external payable {}

    /* view functions */
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function totalSupplyOf(uint256 _pid) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];

        return IERC20(pool.lpToken).balanceOf(address(this));
    }
}