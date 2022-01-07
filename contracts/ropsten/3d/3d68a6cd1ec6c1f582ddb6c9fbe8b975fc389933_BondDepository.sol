/**
 *Submitted for verification at Etherscan.io on 2022-01-07
*/

// SPDX-License-Identifier: AGPL-3.0
pragma solidity =0.7.6;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        assert(a == b * c + (a % b)); // There is no case in which this doesn't hold

        return c;
    }

    // Only used in the  BondingCalculator.sol
    function sqrrt(uint256 a) internal pure returns (uint256 c) {
        if (a > 3) {
            c = a;
            uint256 b = add(div(a, 2), 1);
            while (b < c) {
                c = b;
                b = div(add(div(a, b), b), 2);
            }
        } else if (a != 0) {
            c = 1;
        }
    }
}

library FullMath {
    function fullMul(uint256 x, uint256 y)
        private
        pure
        returns (uint256 l, uint256 h)
    {
        uint256 mm = mulmod(x, y, uint256(-1));
        l = x * y;
        h = mm - l;
        if (mm < l) h -= 1;
    }

    function fullDiv(
        uint256 l,
        uint256 h,
        uint256 d
    ) private pure returns (uint256) {
        uint256 pow2 = d & -d;
        d /= pow2;
        l /= pow2;
        l += h * ((-pow2) / pow2 + 1);
        uint256 r = 1;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        return l * r;
    }

    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        (uint256 l, uint256 h) = fullMul(x, y);

        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        if (h == 0) return l / d;

        require(h < d, "FullMath: FULLDIV_OVERFLOW");
        return fullDiv(l, h, d);
    }
}

library Babylonian {
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

library BitMath {
    function mostSignificantBit(uint256 x) internal pure returns (uint8 r) {
        require(x > 0, "BitMath::mostSignificantBit: zero");

        if (x >= 0x100000000000000000000000000000000) {
            x >>= 128;
            r += 128;
        }
        if (x >= 0x10000000000000000) {
            x >>= 64;
            r += 64;
        }
        if (x >= 0x100000000) {
            x >>= 32;
            r += 32;
        }
        if (x >= 0x10000) {
            x >>= 16;
            r += 16;
        }
        if (x >= 0x100) {
            x >>= 8;
            r += 8;
        }
        if (x >= 0x10) {
            x >>= 4;
            r += 4;
        }
        if (x >= 0x4) {
            x >>= 2;
            r += 2;
        }
        if (x >= 0x2) r += 1;
    }
}

library FixedPoint {
    struct uq112x112 {
        uint224 _x;
    }

    struct uq144x112 {
        uint256 _x;
    }

    uint8 private constant RESOLUTION = 112;
    uint256 private constant Q112 = 0x10000000000000000000000000000;
    uint256 private constant Q224 =
        0x100000000000000000000000000000000000000000000000000000000;
    uint256 private constant LOWER_MASK = 0xffffffffffffffffffffffffffff; // decimal of UQ*x112 (lower 112 bits)

    function decode(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    function decode112with18(uq112x112 memory self)
        internal
        pure
        returns (uint256)
    {
        return uint256(self._x) / 5192296858534827;
    }

    function fraction(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (uq112x112 memory)
    {
        require(denominator > 0, "FixedPoint::fraction: division by zero");
        if (numerator == 0) return FixedPoint.uq112x112(0);

        if (numerator <= uint144(-1)) {
            uint256 result = (numerator << RESOLUTION) / denominator;
            require(result <= uint224(-1), "FixedPoint::fraction: overflow");
            return uq112x112(uint224(result));
        } else {
            uint256 result = FullMath.mulDiv(numerator, Q112, denominator);
            require(result <= uint224(-1), "FixedPoint::fraction: overflow");
            return uq112x112(uint224(result));
        }
    }

    // square root of a UQ112x112
    // lossy between 0/1 and 40 bits
    function sqrt(uq112x112 memory self)
        internal
        pure
        returns (uq112x112 memory)
    {
        if (self._x <= uint144(-1)) {
            return uq112x112(uint224(Babylonian.sqrt(uint256(self._x) << 112)));
        }

        uint8 safeShiftBits = 255 - BitMath.mostSignificantBit(self._x);
        safeShiftBits -= safeShiftBits % 2;
        return
            uq112x112(
                uint224(
                    Babylonian.sqrt(uint256(self._x) << safeShiftBits) <<
                        ((112 - safeShiftBits) / 2)
                )
            );
    }
}


interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

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

library SafeERC20 {
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                to,
                amount
            )
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FROM_FAILED"
        );
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FAILED"
        );
    }

    function safeApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, to, amount)
        );

        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "APPROVE_FAILED"
        );
    }

    function safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}(new bytes(0));

        require(success, "ETH_TRANSFER_FAILED");
    }
}


interface IAuthority {
    /* ========== EVENTS ========== */
    
    event GovernorPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event GuardianPushed(address indexed from, address indexed to, bool _effectiveImmediately);    
    event PolicyPushed(address indexed from, address indexed to, bool _effectiveImmediately);    
    event VaultPushed(address indexed from, address indexed to, bool _effectiveImmediately);    

    event GovernorPulled(address indexed from, address indexed to);
    event GuardianPulled(address indexed from, address indexed to);
    event PolicyPulled(address indexed from, address indexed to);
    event VaultPulled(address indexed from, address indexed to);

    /* ========== VIEW ========== */
    
    function governor() external view returns (address);
    function guardian() external view returns (address);
    function policy() external view returns (address);
    function vault() external view returns (address);
}


abstract contract AccessControlled {

    /* ========== EVENTS ========== */

    event AuthorityUpdated(IAuthority indexed authority);

    string UNAUTHORIZED = "UNAUTHORIZED"; // save gas

    /* ========== STATE VARIABLES ========== */

    IAuthority public authority;


    /* ========== Constructor ========== */

    constructor(IAuthority _authority) {
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }
    

    /* ========== MODIFIERS ========== */
    
    modifier onlyGovernor() {
        require(msg.sender == authority.governor(), UNAUTHORIZED);
        _;
    }
    
    modifier onlyGuardian() {
        require(msg.sender == authority.guardian(), UNAUTHORIZED);
        _;
    }
    
    modifier onlyPolicy() {
        require(msg.sender == authority.policy(), UNAUTHORIZED);
        _;
    }

    modifier onlyVault() {
        require(msg.sender == authority.vault(), UNAUTHORIZED);
        _;
    }
    
    /* ========== GOV ONLY ========== */
    
    function setAuthority(IAuthority _newAuthority) external onlyGovernor {
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }
}


interface ITreasury {
    function deposit(uint256 _amount, address _token, uint256 _profit) external returns (uint256);
    function withdraw(uint256 _amount, address _token) external;
    function tokenValue(address _token, uint256 _amount) external view returns (uint256 value_);
    function mint(address _recipient, uint256 _amount) external;
    function manage(address _token, uint256 _amount) external;
    function incurDebt(uint256 amount_, address token_) external;
    function repayDebtWithReserve(uint256 amount_, address token_) external;
    function excessReserves() external view returns (uint256);
    function baseSupply() external view returns (uint256);
}


interface IBondingCalculator {
    function markdown( address _LP ) external view returns ( uint );
    function valuation( address pair_, uint amount_ ) external view returns ( uint _value );
}


interface ITeller {
    function newBond(address _bonder, address _principal, uint _principalPaid, uint _payout, uint _expires, address _feo) external returns (uint index_);
    function redeemAll(address _bonder) external returns (uint256);
    function redeem(address _bonder, uint256[] memory _indexes) external returns (uint256);
    function getReward() external;
    function setFEReward(uint256 reward) external;
    function updateIndexesFor(address _bonder) external;
    function pendingFor(address _bonder, uint256 _index) external view returns (uint256);
    function pendingForIndexes(address _bonder, uint256[] memory _indexes) external view returns (uint256 pending_);
    function totalPendingFor(address _bonder) external view returns (uint256 pending_);
    function percentVestedFor(address _bonder, uint256 _index) external view returns (uint256 percentVested_);
}


pragma abicoder v2;

contract BondDepository is AccessControlled {
  using FixedPoint for *;
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  /* ======== EVENTS ======== */

  event beforeBond(uint256 index, uint256 price, uint256 internalPrice, uint256 debtRatio);
  event CreateBond(uint256 index, uint256 amount, uint256 payout, uint256 expires);
  event afterBond(uint256 index, uint256 price, uint256 internalPrice, uint256 debtRatio);

  /* ======== STRUCTS ======== */

  // Info about each type of bond
  struct Bond {
    IERC20 principal; // token to accept as payment
    IBondingCalculator calculator; // contract to value principal
    Terms terms; // terms of bond
    bool termsSet; // have terms been set
    uint256 capacity; // capacity remaining
    bool capacityIsPayout; // capacity limit is for payout vs principal
    uint256 totalDebt; // total debt from bond
    uint256 lastDecay; // last block when debt was decayed
  }

  // Info for creating new bonds
  struct Terms {
    uint256 controlVariable; // scaling variable for price
    bool fixedTerm; // fixed term or fixed expiration
    uint256 vestingTerm; // term in blocks (fixed-term)
    uint256 expiration; // block number bond matures (fixed-expiration)
    uint256 conclusion; // block number bond no longer offered
    uint256 minimumPrice; // vs principal value
    uint256 maxPayout; // in thousandths of a %. i.e. 500 = 0.5%
    uint256 maxDebt; // 9 decimal debt ratio, max % total supply created as debt
  }

  /* ======== STATE VARIABLES ======== */

  mapping(uint256 => Bond) public bonds;
  address[] public IDs; // bond IDs

  ITeller public teller; // handles payment

  ITreasury immutable treasury;
  IERC20 immutable OHM;

  /* ======== CONSTRUCTOR ======== */

  constructor(
    address _OHM, 
    address _treasury, 
    address _authority
  ) AccessControlled(IAuthority(_authority)) {
    require(_OHM != address(0));
    OHM = IERC20(_OHM);
    require(_treasury != address(0));
    treasury = ITreasury(_treasury);
  }

  /* ======== POLICY FUNCTIONS ======== */

  /**
   * @notice creates a new bond type
   * @param _principal address
   * @param _calculator address
   * @param _capacity uint
   * @param _capacityIsPayout bool
   */
  function addBond(
    address _principal,
    address _calculator,
    uint256 _capacity,
    bool _capacityIsPayout
  ) external onlyGuardian returns (uint256 id_) {
    Terms memory terms = Terms({
      controlVariable: 0, 
      fixedTerm: false, 
      vestingTerm: 0, 
      expiration: 0, 
      conclusion: 0, 
      minimumPrice: 0, 
      maxPayout: 0, 
      maxDebt: 0
    });

    bonds[IDs.length] = Bond({
      principal: IERC20(_principal), 
      calculator: IBondingCalculator(_calculator), 
      terms: terms, 
      termsSet: false, 
      totalDebt: 0, 
      lastDecay: block.number, 
      capacity: _capacity, 
      capacityIsPayout: _capacityIsPayout
    });

    id_ = IDs.length;
    IDs.push(_principal);
  }

  /**
   * @notice set minimum price for new bond
   * @param _id uint
   * @param _controlVariable uint
   * @param _fixedTerm bool
   * @param _vestingTerm uint
   * @param _expiration uint
   * @param _conclusion uint
   * @param _minimumPrice uint
   * @param _maxPayout uint
   * @param _maxDebt uint
   * @param _initialDebt uint
   */
  function setTerms(
    uint256 _id,
    uint256 _controlVariable,
    bool _fixedTerm,
    uint256 _vestingTerm,
    uint256 _expiration,
    uint256 _conclusion,
    uint256 _minimumPrice,
    uint256 _maxPayout,
    uint256 _maxDebt,
    uint256 _initialDebt
  ) external onlyGuardian {
    require(!bonds[_id].termsSet, "Already set");

    Terms memory terms = Terms({
      controlVariable: _controlVariable, 
      fixedTerm: _fixedTerm, 
      vestingTerm: _vestingTerm, 
      expiration: _expiration, 
      conclusion: _conclusion, 
      minimumPrice: _minimumPrice, 
      maxPayout: _maxPayout, 
      maxDebt: _maxDebt
    });

    bonds[_id].terms = terms;
    bonds[_id].totalDebt = _initialDebt;
    bonds[_id].termsSet = true;
  }

  /**
   * @notice disable existing bond
   * @param _id uint
   */
  function deprecateBond(uint256 _id) external onlyGuardian {
    bonds[_id].capacity = 0;
  }

  /**
   * @notice set teller contract
   * @param _teller address
   */
  function setTeller(address _teller) external onlyGovernor {
    require(address(teller) == address(0));
    require(_teller != address(0));
    teller = ITeller(_teller);
  }

  /* ======== MUTABLE FUNCTIONS ======== */

  /**
   * @notice deposit bond
   * @param _amount uint
   * @param _maxPrice uint
   * @param _depositor address
   * @param _BID uint
   * @param _feo address
   * @return uint
   */
  function deposit(
    uint256 _amount,
    uint256 _maxPrice,
    address _depositor,
    uint256 _BID,
    address _feo
  ) external returns (uint256, uint256) {
    require(_depositor != address(0), "Invalid address");

    Bond memory info = bonds[_BID];

    require(bonds[_BID].termsSet, "Not initialized");
    require(block.number < info.terms.conclusion, "Bond concluded");

    emit beforeBond(_BID, bondPriceInUSD(_BID), bondPrice(_BID), debtRatio(_BID));

    decayDebt(_BID);

    require(info.totalDebt <= info.terms.maxDebt, "Max debt exceeded");
    require(_maxPrice >= _bondPrice(_BID), "Slippage limit: more than max price"); // slippage protection

    uint256 value = treasury.tokenValue(address(info.principal), _amount);
    uint256 payout = payoutFor(value, _BID); // payout to bonder is computed

    // ensure there is remaining capacity for bond
    if (info.capacityIsPayout) {
      // capacity in payout terms
      require(info.capacity >= payout, "Bond concluded");
      info.capacity = info.capacity.sub(payout);
    } else {
      // capacity in principal terms
      require(info.capacity >= _amount, "Bond concluded");
      info.capacity = info.capacity.sub(_amount);
    }

    require(payout >= 10000000, "Bond too small"); // must be > 0.01 OHM ( underflow protection )
    require(payout <= maxPayout(_BID), "Bond too large"); // size protection because there is no slippage

    info.principal.safeTransferFrom(msg.sender, address(treasury), _amount);  // get principal from user wallet
    // info.principal.safeTransfer(address(treasury), _amount); // send payout to treasury

    bonds[_BID].totalDebt = info.totalDebt.add(value); // increase total debt

    uint256 expiration = info.terms.vestingTerm.add(block.number);
    if (!info.terms.fixedTerm) {
      expiration = info.terms.expiration;
    }

    // user info stored with teller
    uint256 index = teller.newBond(_depositor, address(info.principal), _amount, payout, expiration, _feo);

    emit CreateBond(_BID, _amount, payout, expiration);

    return (payout, index);
  }

  /* ======== INTERNAL FUNCTIONS ======== */

  /**
   * @notice reduce total debt
   * @param _BID uint
   */
  function decayDebt(uint256 _BID) internal {
    bonds[_BID].totalDebt = bonds[_BID].totalDebt.sub(debtDecay(_BID));
    bonds[_BID].lastDecay = block.number;
  }

  /* ======== VIEW FUNCTIONS ======== */

  // BOND TYPE INFO

  /**
   * @notice returns data about a bond type
   * @param _BID uint
   * @return principal_ address
   * @return calculator_ address
   * @return totalDebt_ uint
   * @return lastBondCreatedAt_ uint
   */
  function bondInfo(uint256 _BID)
    external
    view
    returns (
      address principal_,
      address calculator_,
      uint256 totalDebt_,
      uint256 lastBondCreatedAt_
    )
  {
    Bond memory info = bonds[_BID];
    principal_ = address(info.principal);
    calculator_ = address(info.calculator);
    totalDebt_ = info.totalDebt;
    lastBondCreatedAt_ = info.lastDecay;
  }

  /**
   * @notice returns terms for a bond type
   * @param _BID uint
   * @return controlVariable_ uint
   * @return vestingTerm_ uint
   * @return minimumPrice_ uint
   * @return maxPayout_ uint
   * @return maxDebt_ uint
   */
  function bondTerms(uint256 _BID)
    external
    view
    returns (
      uint256 controlVariable_,
      uint256 vestingTerm_,
      uint256 minimumPrice_,
      uint256 maxPayout_,
      uint256 maxDebt_
    )
  {
    Terms memory terms = bonds[_BID].terms;
    controlVariable_ = terms.controlVariable;
    vestingTerm_ = terms.vestingTerm;
    minimumPrice_ = terms.minimumPrice;
    maxPayout_ = terms.maxPayout;
    maxDebt_ = terms.maxDebt;
  }

  // PAYOUT

  /**
   * @notice determine maximum bond size
   * @param _BID uint
   * @return uint
   */
  function maxPayout(uint256 _BID) public view returns (uint256) {
    return treasury.baseSupply().mul(bonds[_BID].terms.maxPayout).div(100000);
  }

  /**
   * @notice payout due for amount of treasury value
   * @param _value uint
   * @param _BID uint
   * @return uint
   */
  function payoutFor(uint256 _value, uint256 _BID) public view returns (uint256) {
    return FixedPoint.fraction(_value, bondPrice(_BID)).decode112with18().div(1e16);
  }

  /**
   * @notice payout due for amount of token
   * @param _amount uint
   * @param _BID uint
   */
  function payoutForAmount(uint256 _amount, uint256 _BID) public view returns (uint256) {
    address principal = address(bonds[_BID].principal);
    return payoutFor(treasury.tokenValue(principal, _amount), _BID);
  }

  // BOND PRICE

  /**
   * @notice calculate current bond premium
   * @param _BID uint
   * @return price_ uint
   */
  function bondPrice(uint256 _BID) public view returns (uint256 price_) {
    price_ = bonds[_BID].terms.controlVariable.mul(debtRatio(_BID)).add(1000000000).div(1e7);
    if (price_ < bonds[_BID].terms.minimumPrice) {
      price_ = bonds[_BID].terms.minimumPrice;
    }
  }

  /**
   * @notice calculate current bond price and remove floor if above
   * @param _BID uint
   * @return price_ uint
   */
  function _bondPrice(uint256 _BID) internal returns (uint256 price_) {
    Bond memory info = bonds[_BID];
    price_ = info.terms.controlVariable.mul(debtRatio(_BID)).add(1000000000).div(1e7);
    if (price_ < info.terms.minimumPrice) {
      price_ = info.terms.minimumPrice;
    } else if (info.terms.minimumPrice != 0) {
      bonds[_BID].terms.minimumPrice = 0;
    }
  }

  /**
   * @notice converts bond price to DAI value
   * @param _BID uint
   * @return price_ uint
   */
  function bondPriceInUSD(uint256 _BID) public view returns (uint256 price_) {
    Bond memory bond = bonds[_BID];
    if (address(bond.calculator) != address(0)) {
      price_ = bondPrice(_BID).mul(bond.calculator.markdown(address(bond.principal))).div(100);
    } else {
      price_ = bondPrice(_BID).mul(10**IERC20(address(bond.principal)).decimals()).div(100);
    }
  }

  // DEBT

  /**
   * @notice calculate current ratio of debt to OHM supply
   * @param _BID uint
   * @return debtRatio_ uint
   */
  function debtRatio(uint256 _BID) public view returns (uint256 debtRatio_) {
    debtRatio_ = FixedPoint.fraction(currentDebt(_BID).mul(1e9), treasury.baseSupply()).decode112with18().div(1e18); 
  }

  /**
   * @notice debt ratio in same terms for reserve or liquidity bonds
   * @return uint
   */
  function standardizedDebtRatio(uint256 _BID) public view returns (uint256) {
    Bond memory bond = bonds[_BID];
    if (address(bond.calculator) != address(0)) {
      return debtRatio(_BID).mul(bond.calculator.markdown(address(bond.principal))).div(1e9);
    } else {
      return debtRatio(_BID);
    }
  }

  /**
   * @notice calculate debt factoring in decay
   * @param _BID uint
   * @return uint
   */
  function currentDebt(uint256 _BID) public view returns (uint256) {
    return bonds[_BID].totalDebt.sub(debtDecay(_BID));
  }

  /**
   * @notice amount to decay total debt by
   * @param _BID uint
   * @return decay_ uint
   */
  function debtDecay(uint256 _BID) public view returns (uint256 decay_) {
    Bond memory bond = bonds[_BID];
    uint256 blocksSinceLast = block.number.sub(bond.lastDecay);
    decay_ = bond.totalDebt.mul(blocksSinceLast).div(bond.terms.vestingTerm);
    if (decay_ > bond.totalDebt) {
      decay_ = bond.totalDebt;
    }
  }
}