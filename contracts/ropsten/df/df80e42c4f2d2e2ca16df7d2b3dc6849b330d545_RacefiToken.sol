// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./AddressesLib.sol";

/// @author Racefi Blockchain Dev
contract RacefiToken is ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using AddressesLib for AddressesLib.Addresses;

    uint256 private constant _TOTAL_SUPPLY = (10**8) * DECIMAL_MULTIPLIER;

    uint256 public constant DECIMAL_MULTIPLIER = 10**18;
    bytes32 public constant VESTING_ROLE = keccak256("VESTING_ROLE");
    uint256 public projectedSupply;
    uint256 public netSupply;

    // Tue Oct 05 2021 22:00:00 GMT+0700 (Indochina Time)
    uint256 public constant START_TIME_VESTING = 1633446000;

    mapping(address => VestingInfo) private _vestings;
    AddressesLib.Addresses private _beneficiaryAddresses;

    event ClaimVesting(address beneficiary, uint256 amount);
    event RevokeVesting(address beneficiary, uint256 amount, uint256 claimedAmount);
    event NewVesting(
        address beneficiary,
        uint256 amount,
        uint256 cliff,
        uint256 releaseTotalRounds,
        uint256 daysPerRound,
        uint256 tgePercent,
        uint256 releaseTgeRounds
    );
    event Burn(address account, uint256 amount);

    struct VestingInfo {
        bool isActive;
        uint256 amount; // total amount
        uint256 startTimeVesting; // time start vesting
        uint256 startTimeCliff; // time start cliff
        uint256 claimedAmount; // claimed vest
        uint256 cliff; // time cliff before vesting
        uint256 releaseTotalRounds;
        uint256 daysPerRound;
        uint256 tgePercent;
        uint256 releaseTgeRounds;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Racefi: ADMIN role required");
        _;
    }

    modifier onlyVestingRole() {
        require(hasRole(VESTING_ROLE, _msgSender()), "Racefi: VESTING role required");
        _;
    }

    constructor(address _multiSigAccount) ERC20("Racefi Token", "RAFI") {
        _setupRole(DEFAULT_ADMIN_ROLE, _multiSigAccount);
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        projectedSupply = 0;
        netSupply = 0;
    }

    function addVestingToken(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliff,
        uint256 _releaseTotalRounds,
        uint256 _daysPerRound,
        uint256 _tgePercent,
        uint256 _releaseTgeRounds
    ) external onlyVestingRole {
        require(_beneficiary != address(0), "Racefi: Zero address");
        require(_amount > 0, "Racefi: Amount must be greater than 0");
        require(projectedSupply + _amount <= _TOTAL_SUPPLY, "Racefi: Max supply exceeded");
        require(!_vestings[_beneficiary].isActive, "Racefi: Duplicate vesting address");

        VestingInfo memory info = VestingInfo(
            true,
            _amount,
            START_TIME_VESTING,
            START_TIME_VESTING + 30 days,
            0,
            _cliff,
            _releaseTotalRounds,
            _daysPerRound,
            _tgePercent,
            _releaseTgeRounds
        );

        _vestings[_beneficiary] = info;
        projectedSupply = projectedSupply + _amount;
        _beneficiaryAddresses.push(_beneficiary);

        emit NewVesting(
            _beneficiary,
            _amount,
            _cliff,
            _releaseTotalRounds,
            _daysPerRound,
            _tgePercent,
            _releaseTgeRounds
        );
    }

    function revokeVestingToken(address _beneficiary) external onlyVestingRole {
        VestingInfo memory vestingInfo = _vestings[_beneficiary];

        require(vestingInfo.isActive, "Racefi: Invalid beneficiary");
        uint256 claimableAmount = _getVestingClaimableAmount(_beneficiary);
        uint256 claimedAmount = vestingInfo.claimedAmount;
        if (claimableAmount > 0) {
            require(netSupply + claimableAmount <= _TOTAL_SUPPLY, "Racefi: Max supply exceeded");
            _mint(_beneficiary, claimableAmount);
            claimedAmount = claimedAmount + claimableAmount;
            netSupply = netSupply + claimableAmount;
        }

        _vestings[_beneficiary].isActive = false;
        _vestings[_beneficiary].claimedAmount = claimedAmount;
        projectedSupply = projectedSupply - (vestingInfo.amount - claimedAmount);

        if (claimedAmount == 0) _beneficiaryAddresses.remove(_beneficiary);

        emit RevokeVesting(_beneficiary, vestingInfo.amount, claimedAmount);
    }

    function claimVestingToken() external nonReentrant {
        VestingInfo memory vestingInfo = _vestings[_msgSender()];

        require(vestingInfo.isActive, "Racefi: Not in vesting list");
        uint256 claimableAmount = _getVestingClaimableAmount(_msgSender());
        require(claimableAmount > 0, "Racefi: Nothing to claim");
        require(netSupply + claimableAmount <= _TOTAL_SUPPLY, "Racefi: Max supply exceeded");

        _mint(_msgSender(), claimableAmount);
        _vestings[_msgSender()].claimedAmount = vestingInfo.claimedAmount + claimableAmount;
        netSupply = netSupply + claimableAmount;

        emit ClaimVesting(_msgSender(), claimableAmount);
    }

    function getVestingInfo(address _beneficiary) external view returns (VestingInfo memory) {
        return _vestings[_beneficiary];
    }

    function getBeneficiaryAddresses() external view returns (address[] memory) {
        return _beneficiaryAddresses.getAllAddresses();
    }

    function _getVestingClaimableAmount(address _beneficiary) internal view returns (uint256 claimableAmount) {
        VestingInfo memory info = _vestings[_beneficiary];

        if (!info.isActive) return 0;
        if (block.timestamp < info.startTimeVesting) return 0;

        claimableAmount = 0;
        uint256 tgeReleasedAmount = 0;
        uint256 roundReleasedAmount = 0;
        uint256 releasedAmount = 0;
        uint256 releaseTime = info.startTimeCliff + (info.cliff * 1 days);
        uint256 tgeRounds = ((block.timestamp - info.startTimeVesting) / 30 days) + 1;

        if (info.tgePercent > 0) {
            if (tgeRounds <= info.releaseTgeRounds) {
                tgeReleasedAmount = (info.amount * info.tgePercent * tgeRounds) / (info.releaseTgeRounds * 100);
            } else {
                tgeReleasedAmount = (info.amount * info.tgePercent) / 100;
            }
        }

        if (block.timestamp >= releaseTime) {
            uint256 roundsPassed = ((block.timestamp - releaseTime) / (info.daysPerRound * 1 days)) + 1;

            if (roundsPassed >= info.releaseTotalRounds) {
                roundReleasedAmount = info.amount - tgeReleasedAmount;
            } else {
                roundReleasedAmount = ((info.amount - tgeReleasedAmount) * roundsPassed) / info.releaseTotalRounds;
            }
        }

        releasedAmount = tgeReleasedAmount + roundReleasedAmount;

        if (releasedAmount > info.claimedAmount) {
            claimableAmount = releasedAmount - info.claimedAmount;
        }
    }

    function getVestingClaimableAmount(address _beneficiary) external view returns (uint256) {
        return _getVestingClaimableAmount(_beneficiary);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _TOTAL_SUPPLY;
    }

    function burn(uint256 _amount) public {
        _burn(_msgSender(), _amount);

        projectedSupply = projectedSupply - _amount;
        netSupply = netSupply - _amount;

        emit Burn(_msgSender(), _amount);
    }

    function withdrawERC20(IERC20 _token) external onlyAdmin {
        require(_token.transfer(_msgSender(), _token.balanceOf(address(this))), "Transfer failed");
    }

    receive() external payable {
        revert();
    }
}