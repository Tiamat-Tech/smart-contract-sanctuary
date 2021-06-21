//SPDX-License-Identifier: Unlicense

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";


contract RewardToken is ERC20, ERC20PresetMinterPauser, ERC20Capped {
  using SafeMath for uint256;

  uint256 internal constant SCALE = 1e18;
  uint256 internal constant HALF_SCALE = 5e17;

  uint256 public constant HARD_CAP = 1 * (10 ** 9) * (10 ** 18); // 1 billion
  uint256 public constant MINTING_PERIOD = 126227808; // 4 years

  uint256 public mintingStartTs;
  uint256 public mintingEndTs;

  constructor(address _minter)
  ERC20PresetMinterPauser("Test Token", "TEST")
  ERC20Capped(HARD_CAP) {
    // pause forbidden
    renounceRole(PAUSER_ROLE, _msgSender());
    changeAdmin(_minter);
  }

  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "not admin");
    _;
  }

  modifier onlyMinter() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "not minter");
    _;
  }

  function changeAdmin(address _newAdmin) public onlyAdmin {
    // with scheduling minting, it will be safe to have changeable minter
    _setupRole(DEFAULT_ADMIN_ROLE, _newAdmin);
    // only mint allowed
    _setupRole(MINTER_ROLE, _newAdmin);

    // revoke all roles from current sender
    renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
    renounceRole(MINTER_ROLE, _msgSender());
  }

  function startMinting() public onlyMinter {
    require(mintingStartTs == 0, "minting already started");
    mintingStartTs = block.timestamp;
    mintingEndTs = mintingStartTs + MINTING_PERIOD;
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount)
  internal override(ERC20, ERC20PresetMinterPauser, ERC20Capped) {
    if (from == address(0)) {// it is mint
      require(mintingStartTs != 0, "minting not started");
      require(totalSupply().add(amount) <= maxTotalSupplyForCurrentBlock(), "limit exceeded");
    }
    super._beforeTokenTransfer(from, to, amount);
  }

  function currentWeek() public view returns (uint256){
    if (mintingStartTs == 0) {// not started yet
      return 0;
    }
    return block.timestamp.sub(mintingStartTs).div(1 weeks).add(1);
  }

  function maxTotalSupplyForCurrentBlock() public view returns (uint256){
    uint256 allWeeks = MINTING_PERIOD / 1 weeks;

    uint256 week = Math.min(allWeeks, currentWeek());

    if (week == 0) {
      return 0;
    }
    if (week >= MINTING_PERIOD / 1 weeks) {
      return HARD_CAP;
    }

    uint256 finalMultiplier = _log2(allWeeks.add(1).mul(10 ** 18));

    uint256 baseWeekEmission = HARD_CAP / finalMultiplier;

    uint256 multiplier = _log2(week.add(1).mul(10 ** 18));

    uint256 maxTotalSupply = baseWeekEmission.mul(multiplier);

    return Math.min(maxTotalSupply, HARD_CAP);
  }

  /*********************************************
  *              PRB-MATH                      *
  *   https://github.com/hifi-finance/prb-math *
  * Lib has 0.8 sol version but our code is 0.7*
  **********************************************/

  /// @notice Calculates the binary logarithm of x.
  ///
  /// @dev Based on the iterative approximation algorithm.
  /// https://en.wikipedia.org/wiki/Binary_logarithm#Iterative_approximation
  ///
  /// Requirements:
  /// - x must be greater than or equal to SCALE, otherwise the result would be negative.
  ///
  /// Caveats:
  /// - The results are nor perfectly accurate to the last decimal,
  ///   due to the lossy precision of the iterative approximation.
  ///
  /// @param x The unsigned 60.18-decimal fixed-point number for which
  ///           to calculate the binary logarithm.
  /// @return result The binary logarithm as an unsigned 60.18-decimal fixed-point number.
  function _log2(uint256 x) public pure returns (uint256 result) {
    require(x >= SCALE, "log input should be greater 1e18");

    // Calculate the integer part of the logarithm
    // and add it to the result and finally calculate y = x * 2^(-n).
    uint256 n = mostSignificantBit(x / SCALE);

    // The integer part of the logarithm as an unsigned 60.18-decimal fixed-point number.
    // The operation can't overflow because n is maximum 255 and SCALE is 1e18.
    uint256 rValue = n * SCALE;

    // This is y = x * 2^(-n).
    uint256 y = x >> n;

    // If y = 1, the fractional part is zero.
    if (y == SCALE) {
      return rValue;
    }

    // Calculate the fractional part via the iterative approximation.
    // The "delta >>= 1" part is equivalent to "delta /= 2", but shifting bits is faster.
    for (uint256 delta = HALF_SCALE; delta > 0; delta >>= 1) {
      y = (y * y) / SCALE;

      // Is y^2 > 2 and so in the range [2,4)?
      if (y >= 2 * SCALE) {
        // Add the 2^(-m) factor to the logarithm.
        rValue += delta;

        // Corresponds to z/2 on Wikipedia.
        y >>= 1;
      }
    }
    return rValue;
  }

  /// @notice Finds the zero-based index of the first one in the binary representation of x.
  /// @dev See the note on msb in the "Find First Set"
  ///      Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
  /// @param x The uint256 number for which to find the index of the most significant bit.
  /// @return msb The index of the most significant bit as an uint256.
  function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
    if (x >= 2 ** 128) {
      x >>= 128;
      msb += 128;
    }
    if (x >= 2 ** 64) {
      x >>= 64;
      msb += 64;
    }
    if (x >= 2 ** 32) {
      x >>= 32;
      msb += 32;
    }
    if (x >= 2 ** 16) {
      x >>= 16;
      msb += 16;
    }
    if (x >= 2 ** 8) {
      x >>= 8;
      msb += 8;
    }
    if (x >= 2 ** 4) {
      x >>= 4;
      msb += 4;
    }
    if (x >= 2 ** 2) {
      x >>= 2;
      msb += 2;
    }
    if (x >= 2 ** 1) {
      // No need to shift x any more.
      msb += 1;
    }
  }

}