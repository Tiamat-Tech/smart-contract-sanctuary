pragma solidity ^0.4.26;

import "./SafeMath.sol";
import "./Gather_coin.sol";
import "./Ownable.sol";


contract VestingPool is Ownable {
  using SafeMath for uint256;

  // The token being vested
  GatherToken public token;

  // Category name identifiers
  bytes32 public privateCategory = keccak256("privateCategory");
  bytes32 public platformCategory = keccak256("platformCategory");
  bytes32 public seedCategory = keccak256("seedCategory");
  bytes32 public foundationCategory = keccak256("foundationCategory");
  bytes32 public marketingCategory = keccak256("marketingCategory");
  bytes32 public teamCategory = keccak256("teamCategory");
  bytes32 public advisorCategory = keccak256("advisorCategory");

  bool public isVestingStarted;
  uint256 public vestingStartDate;

  struct vestingInfo {
    uint256 limit;
    uint256 released;
    uint256[] scheme;
    mapping(address => bool) adminEmergencyFirstApprove;
    mapping(address => bool) adminEmergencySecondApprove;
    bool multiownedEmergencyFirstApprove;
    bool multiownedEmergencySecondApprove;
    uint256 initEmergencyDate;
  }

  mapping(bytes32 => vestingInfo) public vesting;

  uint32 private constant SECONDS_PER_DAY = 24 * 60 * 60;
  uint32 private constant SECONDS_PER_MONTH = SECONDS_PER_DAY * 30;

  address public admin1address;
  address public admin2address;

  event Withdraw(address _to, uint256 _amount);


  constructor(address _token) public {
    require(_token != address(0), "Gath3r: Token address must be set for vesting");

    token = GatherToken(_token);

    // Setup vesting data for each category
    _initVestingData();
  }

  modifier isNotStarted() {
    require(!isVestingStarted, "Gath3r: Vesting is already started");
    _;
  }

  modifier isStarted() {
    require(isVestingStarted, "Gath3r: Vesting is not started yet");
    _;
  }

  modifier approvedByAdmins(bytes32 _category) {
    require(vesting[_category].adminEmergencyFirstApprove[admin1address], "Gath3r: Emergency transfer must be approved by Admin 1");
    require(vesting[_category].adminEmergencyFirstApprove[admin2address], "Gath3r: Emergency transfer must be approved by Admin 2");
    require(vesting[_category].adminEmergencySecondApprove[admin1address], "Gath3r: Emergency transfer must be approved twice by Admin 1");
    require(vesting[_category].adminEmergencySecondApprove[admin2address], "Gath3r: Emergency transfer must be approved twice by Admin 2");
    _;
  }

  modifier approvedByMultiowned(bytes32 _category) {
    require(vesting[_category].multiownedEmergencyFirstApprove, "Gath3r: Emergency transfer must be approved by Multiowned");
    require(vesting[_category].multiownedEmergencySecondApprove, "Gath3r: Emergency transfer must be approved twice by Multiowned");
    _;
  }

  function startVesting() public onlyOwner isNotStarted {
    vestingStartDate = now;
    isVestingStarted = true;
  }

  // Two Admins for emergency transfer
  function addAdmin1address(address _admin) public onlyOwner {
    require(_admin != address(0), "Gath3r: Admin 1 address must be exist for emergency transfer");
    _resetAllAdminApprovals(_admin);
    admin1address = _admin;
  }

  function addAdmin2address(address _admin) public onlyOwner {
    require(_admin != address(0), "Gath3r: Admin 2 address must be exist for emergency transfer");
    _resetAllAdminApprovals(_admin);
    admin2address = _admin;
  }

  function multipleWithdraw(address[] _addresses, uint256[] _amounts, bytes32 _category) public onlyOwner isStarted {
    require(_addresses.length == _amounts.length, "Gath3r: Amount of adddresses must be equal withdrawal amounts length");

    uint256 withdrawalAmount;
    uint256 availableAmount = getAvailableAmountFor(_category);
    for(uint i = 0; i < _amounts.length; i++) {
      withdrawalAmount = withdrawalAmount.add(_amounts[i]);
    }
    require(withdrawalAmount <= availableAmount, "Gath3r: Withdraw amount more than available limit");

    for(i = 0; i < _addresses.length; i++) {
      _withdraw(_addresses[i], _amounts[i], _category);
    }
  }

  function getAvailableAmountFor(bytes32 _category) public view returns (uint256) {
    uint256 currentMonth = now.sub(vestingStartDate).div(SECONDS_PER_MONTH);
    uint256 totalUnlockedAmount;

    for(uint8 i = 0; i <= currentMonth; i++ ) {
      totalUnlockedAmount = totalUnlockedAmount.add(vesting[_category].scheme[i]);
    }

    return totalUnlockedAmount.sub(vesting[_category].released);
  }

  function firstAdminEmergencyApproveFor(bytes32 _category, address _admin) public onlyOwner {
    require(_admin == admin1address || _admin == admin2address, "Gath3r: Approve for emergency address must be from admin address");
    require(!vesting[_category].adminEmergencyFirstApprove[_admin]);

    if (vesting[_category].initEmergencyDate == 0) {
      vesting[_category].initEmergencyDate = now;
    }
    vesting[_category].adminEmergencyFirstApprove[_admin] = true;
  }

  function secondAdminEmergencyApproveFor(bytes32 _category, address _admin) public onlyOwner {
    require(_admin == admin1address || _admin == admin2address, "Gath3r: Approve for emergency address must be from admin address");
    require(vesting[_category].adminEmergencyFirstApprove[_admin]);
    require(now.sub(vesting[_category].initEmergencyDate) > SECONDS_PER_DAY);

    vesting[_category].adminEmergencySecondApprove[_admin] = true;
  }

  function firstMultiownedEmergencyApproveFor(bytes32 _category) public onlyOwner {
    require(!vesting[_category].multiownedEmergencyFirstApprove);

    if (vesting[_category].initEmergencyDate == 0) {
      vesting[_category].initEmergencyDate = now;
    }
    vesting[_category].multiownedEmergencyFirstApprove = true;
  }

  function secondMultiownedEmergencyApproveFor(bytes32 _category) public onlyOwner {
    require(vesting[_category].multiownedEmergencyFirstApprove, "Gath3r: Second multiowned approval must be after fisrt multiowned approval");
    require(now.sub(vesting[_category].initEmergencyDate) > SECONDS_PER_DAY);

    vesting[_category].multiownedEmergencySecondApprove = true;
  }

  function emergencyTransferFor(bytes32 _category, address _to) public onlyOwner approvedByAdmins(_category) approvedByMultiowned(_category) {
    require(_to != address(0), "Gath3r: Address must be transmit for emergency transfer");
    uint256 limit = vesting[_category].limit;
    uint256 released = vesting[_category].released;
    uint256 availableAmount = limit.sub(released);
    _withdraw(_to, availableAmount, _category);
  }

  function _withdraw(address _beneficiary, uint256 _amount, bytes32 _category) internal {
    token.transfer(_beneficiary, _amount);
    vesting[_category].released = vesting[_category].released.add(_amount);

    emit Withdraw(_beneficiary, _amount);
  }

  function _resetAllAdminApprovals(address _admin) internal {
    vesting[seedCategory].adminEmergencyFirstApprove[_admin] = false;
    vesting[seedCategory].adminEmergencySecondApprove[_admin] = false;
    vesting[foundationCategory].adminEmergencyFirstApprove[_admin] = false;
    vesting[foundationCategory].adminEmergencySecondApprove[_admin] = false;
    vesting[marketingCategory].adminEmergencyFirstApprove[_admin] = false;
    vesting[marketingCategory].adminEmergencySecondApprove[_admin] = false;
    vesting[teamCategory].adminEmergencyFirstApprove[_admin] = false;
    vesting[teamCategory].adminEmergencySecondApprove[_admin] = false;
    vesting[advisorCategory].adminEmergencyFirstApprove[_admin] = false;
    vesting[advisorCategory].adminEmergencySecondApprove[_admin] = false;
  }

  function _amountWithPrecision(uint256 _amount) internal view returns (uint256) {
    return _amount.mul(10 ** uint(token.decimals()));
  }

  // Vesting data for public sale category
  function _initVestingData() internal {
    // Vesting data for private sale category
    vesting[privateCategory].limit = _expandToDecimals(20000000);
    vesting[privateCategory].scheme = [
      /* initial amount */
      10500000,
      /* M+1 M+2 */
      10500000, 9000000
    ];

    // Vesting data for platform category
    vesting[platformCategory].limit = _expandToDecimals(30000000);
    vesting[platformCategory].scheme = [
      /* initial amount */
      30000000
    ];

    // Vesting data for seed category
    vesting[seedCategory].limit = _expandToDecimals(22522500);
    vesting[seedCategory].scheme = [
      /* initial amount */
      5630625,
      /* M+1 M+2 M+3 M+4 M+5 */
      3378375, 3378375, 3378375, 3378375, 3378375
    ];

    // Vesting data for foundation category
    vesting[foundationCategory].limit = _expandToDecimals(193477500);
    vesting[foundationCategory].scheme = [
      /* initial amount */
      0,
      /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
      0, 0, 0, 0, 0, 6000000, 6000000, 6000000, 6000000, 6000000, 6000000, 6000000,
      /* Y+2 */
      4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000,
      /* Y+3 */
      4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000, 4000000,
      /* Y+4 */
      3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000, 3000000,
      /* Y+5 */
      19477500
    ];

    // Vesting data for marketing category
    vesting[marketingCategory].limit = _expandToDecimals(50000000);
    vesting[marketingCategory].scheme = [
      /* initial amount */
      0,
      /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
      0, 0, 2000000, 2000000, 2000000, 2000000, 2000000, 2000000, 2000000, 2000000, 2000000, 2000000,
      /* Y+2 */
      1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000, 1500000,
      /* Y+3 */
      1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000, 1000000
    ];

    // Vesting data for team category
    vesting[teamCategory].limit = _expandToDecimals(50000000);
    vesting[teamCategory].scheme = [
      /* initial amount */
      0,
      /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 M+10 M+11 M+12 */
      0, 0, 0, 0, 0, 7000000, 0, 0, 0, 7000000, 0, 0,
      /* Y+2 */
      0, 7000000, 0, 0, 0, 7000000, 0, 0, 7000000, 0, 0, 0,
      /* Y+3 */
      0, 7500000, 0, 0, 0, 7500000
    ];

    // Vesting data for advisor category
    vesting[advisorCategory].limit = _expandToDecimals(24000000);
    vesting[advisorCategory].scheme = [
      /* initial amount */
      0,
      /* M+1 M+2 M+3 M+4 M+5 M+6 M+7 M+8 M+9 */
      0, 0, 6000000, 6000000, 4500000, 4500000, 0, 1500000, 1500000
    ];

    _expandToDecimalsVestingScheme(privateCategory);
    _expandToDecimalsVestingScheme(platformCategory);
    _expandToDecimalsVestingScheme(seedCategory);
    _expandToDecimalsVestingScheme(foundationCategory);
    _expandToDecimalsVestingScheme(marketingCategory);
    _expandToDecimalsVestingScheme(teamCategory);
    _expandToDecimalsVestingScheme(advisorCategory);
  }

  function _expandToDecimalsVestingScheme(bytes32 _category) internal returns (uint256[]) {
    for(uint i = 0; i < vesting[_category].scheme.length; i++) {
      vesting[_category].scheme[i] = _expandToDecimals(vesting[_category].scheme[i]);
    }
  }

  function _expandToDecimals(uint256 _amount) internal view returns (uint256) {
    return _amount.mul(10 ** uint(token.decimals()));
  }
}