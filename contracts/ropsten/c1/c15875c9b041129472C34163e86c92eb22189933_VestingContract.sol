pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingContract is Context, Ownable {
    using SafeERC20 for IERC20;

    address[] current_beneficiaries;

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

    uint256 lock_duration = 31556926; //currentMonthration set to 12 months

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
        //this will contain the active ids and released ids and count(how many time a beneficiary has been set, may be helpful)
        uint256[] active_ids;
        uint256[] released_ids;
        uint256 count;
        //  uint256 released;
    }

    VestingDetails[] public vesting;

    mapping(address => BeneficiaryDetails) public beneficiary_details;

    event BeneficiarySet(
        address indexed to,
        uint256 claim_id,
        uint256 amount,
        uint256 start_timee,
        uint256 release_time
    );

    event released(
        //(id, Month, tokens);(
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
        uint256 start_time = block.timestamp;
        uint256 end = start_time + lock_duration;
        uint256 length = vesting.length;
        token().safeTransferFrom(_msgSender(), address(this), amount);
        vesting.push(
            VestingDetails(
                length,
                beneficiary,
                amount,
                start_time,
                end,
                0,
                true,
                false,
                1
            )
        );
        beneficiary_details[beneficiary].active_ids.push(length);
        beneficiary_details[beneficiary].count++;
        current_beneficiaries.push(beneficiary);
        emit BeneficiarySet(beneficiary, length, amount, start_time, end);
    }

    function release(
        address beneficiary,
        uint256 id,
        uint256 CurrentMonth
    ) public checkOwner returns (bool) {
        VestingDetails memory vesting_details = vesting[id];
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

        uint256 currentMonth = CurrentMonth;
        uint256 claimed_amount = 0;
        bool done = false;

        // uint256 currentMonth = a;
        // uint256 claimed_amount = 0;
        // bool done = false;

        claimed_amount = (vesting_details.amount * currentRate) / 100;
        update(id, claimed_amount);

        if (currentMonth == 12) {
            done = true;
        }

        return
            _releaseWithAmount(
                id,
                beneficiary,
                claimed_amount,
                done,
                currentMonth
            );
    }

    function update(uint256 id, uint256 ca) internal {
        VestingDetails memory vesting_details = vesting[id];
        vesting_details.amount = vesting_details.amount - ca;
    }

    function _releaseWithAmount(
        uint256 id,
        address ben,
        uint256 claimed_amount,
        bool _d,
        uint256 cm
    ) internal returns (bool) {
        bool d = _d;
        if (claimed_amount > 0) {
            if (d == true) {
                vesting[id].status = false;
                vesting[id].released = true;
                beneficiary_details[ben].released_ids.push(id);
            }
            //address sender = ben();
            // vesting[id].a1 ++ ;
            vesting[id].claimed_at = block.timestamp;
            vesting[id].nextPeriod = cm + 1;
            // beneficiary_details[ben].released++;
            token().safeTransfer(ben, claimed_amount);
            emit released(ben, id, claimed_amount, cm);
            return true;
        }
        return false;
    }
}