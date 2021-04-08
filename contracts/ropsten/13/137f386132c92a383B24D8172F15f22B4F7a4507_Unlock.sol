pragma solidity >=0.6.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/VestingLibrary.sol";

contract Unlock is ReentrancyGuard, Pausable, Ownable {
    
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using VestingLibrary for VestingLibrary.Data;

    event Withdraw(address indexed sender, uint amount);
    event EmergencyWithdraw(address indexed owner, uint amount);

    IERC20 immutable private token;

    VestingLibrary.Data private vestingData;
    mapping(address => uint) public lockUpAmountOf;
    mapping(address => uint) public vestedAmountOf;
    uint public totalLocked;
    uint public presaleEndTime;

    constructor(
        address _token,
        uint16 _cliffPercentage,
        uint32 _cliffDuration,
        uint32 _vestingDuration,
        uint32 _vestingInterval,
        uint _presaleEndTime
    ) public {
        token = IERC20(_token);
        presaleEndTime = _presaleEndTime;
        vestingData.initialize(
            _cliffPercentage,
            _cliffDuration,
            _vestingDuration,
            _vestingInterval
        );

        _pause();
    }

    function setPaused(bool _paused) external onlyOwner {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setLockup(address[] calldata _accounts, uint[] calldata _amounts) external onlyOwner {
        require(_accounts.length == _amounts.length, "Unlock: LENGTH");
        for (uint i; i < _accounts.length; ++i) {
            // it's okay to set address as zero to reset the user-related data
            totalLocked = totalLocked.sub(lockUpAmountOf[_accounts[i]]).add(_amounts[i]);
            lockUpAmountOf[_accounts[i]] = _amounts[i];
        }
    }

    function emergencyWithdraw() external onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(owner(), balance);
        emit EmergencyWithdraw(owner(), balance);
    }

    function withdraw() external whenNotPaused {
        uint unlocked = vestingData.availableInputAmount(lockUpAmountOf[msg.sender], vestedAmountOf[msg.sender], presaleEndTime);
        require(unlocked > 0, "Unlock: ZERO");
        vestedAmountOf[msg.sender] = vestedAmountOf[msg.sender].add(unlocked);
        IERC20(token).safeTransfer(msg.sender, unlocked);
        emit Withdraw(msg.sender, unlocked);
    }

    function unlockedAmountOf(address _account) external view returns (uint) {
        return vestingData.availableInputAmount(lockUpAmountOf[_account], vestedAmountOf[_account], presaleEndTime);
    }
}