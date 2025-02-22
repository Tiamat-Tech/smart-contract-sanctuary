// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Aion {
    address public owner;
    uint256 public serviceFee;
    uint256 public AionID;
    uint256 public feeChangeInterval;
    mapping(address => address) public clientAccount;
    mapping(uint256 => bytes32) public scheduledCalls;

    event ExecutedCallEvent(
        address indexed from,
        uint256 indexed AionID,
        bool TxStatus,
        bool TxStatus_cancel,
        bool reimbStatus
    );
    event ScheduleCallEvent(
        uint256 indexed blocknumber,
        address indexed from,
        address to,
        uint256 value,
        uint256 gaslimit,
        uint256 gasprice,
        uint256 fee,
        bytes data,
        uint256 indexed AionID,
        bool schedType
    );
    event CancellScheduledTxEvent(
        address indexed from,
        uint256 Total,
        bool Status,
        uint256 indexed AionID
    );
    event feeChanged(uint256 newfee, uint256 oldfee);

    function cancellScheduledTx(
        uint256 blocknumber,
        address from,
        address to,
        uint256 value,
        uint256 gaslimit,
        uint256 gasprice,
        uint256 fee,
        bytes calldata data,
        uint256 aionId,
        bool schedType
    ) external virtual returns (bool);

    function ScheduleCall(
        uint256 blocknumber,
        address to,
        uint256 value,
        uint256 gaslimit,
        uint256 gasprice,
        bytes memory data,
        bool schedType
    ) public payable virtual returns (uint256, address);
}

contract TokenVesting {
    using SafeERC20 for IERC20;
    IERC20 private _token;

    function getToken() external view returns (address) {
        return address(_token);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    ) public {}
}

contract ScheduleVesting {
    // Aion aion;
    TokenVesting tokenVesting;
    uint256 estimatedTime;

    constructor() {
        estimatedTime = block.timestamp + 3 minutes;
    }

    receive() external payable {}

    fallback() external payable {}

    function schedule_vest() public returns (uint256) {
        Aion aion = Aion(0xFcFB45679539667f7ed55FA59A15c8Cad73d9a4E);
        tokenVesting = TokenVesting(0x22f25a0896eFCa162Cfc650f60B7F9dd5dB7A083);
        bytes memory data = abi.encodeWithSelector(bytes4(keccak256("vest()")));
        uint256 callCost = 200000 * 1e9 + aion.serviceFee();
        return callCost;

        // (uint256 a, address b) = aion.ScheduleCall{value: callCost}(
        //     estimatedTime,
        //     address(this),
        //     0,
        //     200000,
        //     1e9,
        //     data,
        //     false
        // );

        // return a;
    }

    function vest() public {
        // tokenVesting.createVestingSchedule(
        //     0x0bBEf1ac8fa18729945194fCb3a977aD48682ECa,
        //     estimatedTime + 1 minutes,
        //     0,
        //     1,
        //     1,
        //     true,
        //     10000000000000000000
        // );
    }
}