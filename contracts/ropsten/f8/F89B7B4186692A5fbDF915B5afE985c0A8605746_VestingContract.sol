pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";        
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingContract is Context, Ownable {
    using SafeERC20 for IERC20;

    uint256[12] internal rate = [
        uint256(10),
        1,
        3,
        4,
        5,
        7,
        8,
        10,
        11,
        12,
        14,
        15
    ];

    IERC20 private immutable _token;

    uint256 internal lock_duration = 31556926; 

    constructor(IERC20 token) public {
        _token = token;
    }

    modifier checkOwner() {
        require(
            _msgSender() == owner(),
            "Only owner can perform the operation"
        );
        _;
    }

    struct VestingDetails {
        uint256 id;
        address beneficiary;
        uint256 amount;
        uint256 start_time;
        uint256 release_time;
        uint256 claimed_at;
        bool status;
        bool released;
        uint256 nextPeriod;
    }

    struct BeneficiaryDetails {
        uint256 id;
        uint256 count;
        uint256 lockedAmount;
        uint256 unlockedAmount;
    }

    VestingDetails[] public vestings;

    mapping(address => BeneficiaryDetails) public beneficiary_details;

    event BeneficiarySet(
        address indexed to,
        uint256 claim_id,
        uint256 amount,
        uint256 start_timee,
        uint256 release_time
    );

    event released(
        address indexed to,
        uint256 claim_id,
        uint256 amount,
        uint256 duration
    );

    function token() public view virtual returns (IERC20) {
        return _token;
    }

    function setBeneficiary(address beneficiary, uint256 amount)    
        public
        checkOwner
    {
        vestings.push(
            VestingDetails(
                vestings.length + 1,
                beneficiary,
                amount,
                block.timestamp,
                block.timestamp + lock_duration,
                0,
                true,
                false,
                1
            )
        );
        beneficiary_details[beneficiary].lockedAmount = amount;
        beneficiary_details[beneficiary].id = vestings.length;
        emit BeneficiarySet(beneficiary, vestings.length, amount, block.timestamp, block.timestamp + lock_duration);
    }

    function release(
        address beneficiary,
        uint256 id,
        uint256 CurrentMonth
    ) public checkOwner returns (bool) {
        VestingDetails memory vesting_details = vestings[id];
        uint256 _currentMonth = vesting_details.nextPeriod;
        require(

            vesting_details.beneficiary == beneficiary,
            "Invalid Beneficiary"
        );
        require(
            vesting_details.status == true,
            "All the tokens are released to the wallet"
        );
        require(
            CurrentMonth != 0 && CurrentMonth == _currentMonth,
            "Either you have overlapped or Already released !!"
        );
        uint256 currentRate = rate[CurrentMonth - 1];
        uint256 claimed_amount = 0;
        bool done = false;
        claimed_amount = (vesting_details.amount * currentRate) / 100;
        update(id, claimed_amount);
        if (CurrentMonth == 12) {
            done = true;
        }
        return
            _releaseWithAmount(
                id,
                beneficiary,
                claimed_amount,
                done,
                CurrentMonth
            );
    }

    function update(uint256 id, uint256 ca) internal view{
        VestingDetails memory vesting_details = vestings[id];
        vesting_details.amount = vesting_details.amount - ca;
    }

    function _releaseWithAmount(
        uint256 id,
        address ben,
        uint256 claimed_amount,
        bool _d,
        uint256 cm
    ) internal returns (bool) {
        if (claimed_amount > 0) {
            if (_d == true) {
                vestings[id].status = false;
                vestings[id].released = true;
            }
            vestings[id].claimed_at = block.timestamp;
            vestings[id].nextPeriod = cm + 1;
            token().safeTransferFrom(owner(), ben, claimed_amount);
            beneficiary_details[ben].lockedAmount -= claimed_amount ;
            beneficiary_details[ben].unlockedAmount += claimed_amount ;
            emit released(ben, id, claimed_amount, cm);
            return true;
        }
        return false;
    }
}