// "SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol"; 

contract Staking {
    using SafeMath for uint256;

    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewAdmin(address indexed newAdmin);
    event NewLaunchTime(uint256 newLaunchTime);
    event NewPendingVault(address indexed newPendingVault);
    event NewVault(address indexed newVault);
    event EmergencyCall(address indexed vault, uint256 amount);

    uint256 private constant _rewardSupply  = 2800000e18; // 2.8 million ZONE, 10%
    uint256 private constant _stakeLimit  = 19600000e18; // 19.6 million ZONE, 70% (30% at owner’s address + 40% Crowdsale)

    uint internal constant DURATION_30 = 30;
    uint internal constant DURATION_60 = 60;
    uint internal constant DURATION_90 = 90;

    /* Time of the staking opened (ex: 1614556800 -> 2021-03-01T00:00:00Z) */
    uint256 public LAUNCH_TIME;
    
    address public vault;
    address public pendingVault;

    address public admin;
    address public pendingAdmin;

    /// @notice The address of the Compound governance token
    IERC20 public zoneToken;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    modifier isAdmin(address _account) {
        require(admin == _account, "Restricted Access!");
        _;
    }

    constructor(address _zoneToken, address _vaultAddr) public {
        admin = msg.sender;
        vault = _vaultAddr;
        zoneToken = IERC20(_zoneToken);

        LAUNCH_TIME = block.timestamp  / 1  days * 1  days;
    }

    /* Update admin address */
    function setPendingAdmin(address _pendingAdmin) external isAdmin(msg.sender) {
        pendingAdmin = _pendingAdmin;
        emit NewPendingAdmin(pendingAdmin);
    }

    function acceptAdmin() external {
        require(msg.sender == pendingAdmin, "acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);
        emit NewAdmin(admin);
    }

    /**
     * @dev PUBLIC FACING: External helper for the current day number since launch time
     * @return Current day number (zero-based)
     */
    function currentDay() external view returns (uint256)
    {
        return _currentDay();
    }

    function _currentDay() internal view returns (uint256)
    {
        if (block.timestamp < LAUNCH_TIME){
            return 0;
        }else{
            return (block.timestamp - LAUNCH_TIME) / 1 days;
        }
    }

    /* Set launch time as today */
    function launchToday() external isAdmin(msg.sender) {
        require(_currentDay() < DURATION_30, "launchToday: We can't change the launch time because already reward started.");

        LAUNCH_TIME = block.timestamp  / 1  days * 1  days;
        emit NewLaunchTime(LAUNCH_TIME);
    }

    /* Update vault address */
    function setPendingVault(address _pendingVault) external isAdmin(msg.sender) {
        pendingVault = _pendingVault;
        emit NewPendingVault(pendingVault);
    }

    function acceptVault() external {
        require(msg.sender == pendingVault, "acceptVault: Call must come from pendingVault.");
        admin = msg.sender;
        pendingVault = address(0);
        emit NewVault(vault);
    }

    /* EMERGENCY: send back all assets */
    function emergencyCall() external isAdmin(msg.sender) {
        uint256 balance = zoneToken.balanceOf(address(this));
        if (0 < balance && vault != address(0)) {
            zoneToken.transfer(vault, balance);
            emit EmergencyCall(vault, balance);
        }
    }

}