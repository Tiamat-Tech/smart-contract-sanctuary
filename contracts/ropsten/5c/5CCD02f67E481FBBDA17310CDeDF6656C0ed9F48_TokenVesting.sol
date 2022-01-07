// contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Token is ERC20 {
    string constant NAME = "MET Token";
    string constant SYMBOL = "MET";
    uint256 constant TOTAL_SUPPLY = 500000000000000000000000000;

    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}

abstract contract Aion {
    uint256 public serviceFee;

    function ScheduleCall(
        uint256 blocknumber,
        address to,
        uint256 value,
        uint256 gaslimit,
        uint256 gasprice,
        bytes memory data,
        bool schedType
    ) public payable virtual returns (uint256);
}

contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        address beneficiary;
        uint256 start;
        uint256 amountTotal;
    }
    uint256 vestingSchedulesCount;
    mapping(uint256 => VestingSchedule) private vestingSchedules;
    Aion aion;

    IERC20 private immutable _token;

    constructor(address token_) {
        require(token_ != address(0x0));
        _token = IERC20(token_);
        vestingSchedulesCount = 0;
    }

    receive() external payable {}

    fallback() external payable {}

    function getToken() external view returns (address) {
        return address(_token);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _amount
    ) public onlyOwner {
        uint256 vestingScheduleId = vestingSchedulesCount;
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _beneficiary,
            _start,
            _amount
        );
        vestingSchedulesCount.add(1);

        aion = Aion(0xFcFB45679539667f7ed55FA59A15c8Cad73d9a4E);
        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("release(uint256)")),
            vestingScheduleId
        );
        uint256 callCost = 200000 * 1e9 + aion.serviceFee();
        aion.ScheduleCall{value: callCost}(
            block.number + 15,
            address(this),
            0,
            200000,
            1e9,
            data,
            false
        );
    }

    function release(uint256 vestingScheduleId) public nonReentrant {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        _token.safeTransfer(beneficiaryPayable, vestingSchedule.amountTotal);
    }

    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesCount;
    }

    function getVestingSchedule(uint256 vestingScheduleId)
        public
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[vestingScheduleId];
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}