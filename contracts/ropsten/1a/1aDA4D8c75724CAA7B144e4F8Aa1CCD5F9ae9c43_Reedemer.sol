// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IFluentUSDPlus {
    function requestBurnUSDPlus(
        bytes32 _refId,
        address _redeemerContractAddress,
        address _redeemerPerson,
        address _fedMemberID,
        uint256 _amount
    ) external returns (bool isRequested);

    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

//TODO: Verify how to create a general blacklist outside Federation Member control

/// @title Federation member´s Contract for redeem balance
/// @author Fluent Group - Development team
/// @notice Use this contract for request US dollars back
/// @dev
contract Reedemer is Pausable, AccessControl {
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");    
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public fedMemberId;

    address fluentUSDPlusAddress;

    struct BurnTicket {
        bytes32 refId;
        address from;
        uint256 amount;
        uint256 placedBlock;
        uint256 confirmedBlock;
        bool status;
        bool approved;
        bool burned;
    }

    /// @dev _refId => ticket
    mapping(bytes32 => BurnTicket) burnTickets;

    /// @dev Array of _refId
    bytes32[] public _refIds;

    constructor(
        address _fedMemberAddress,
        address _fluentUSDPlusAddress,
        address _fedMemberId
    ) {
        _grantRole(BURNER_ROLE, _fluentUSDPlusAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, _fedMemberAddress);
        _grantRole(APPROVER_ROLE, _fedMemberAddress);
        _grantRole(PAUSER_ROLE, _fedMemberAddress);

        fluentUSDPlusAddress = _fluentUSDPlusAddress;

        ///       REMOVE IT =P
        // IERC20(fluentUSDPlusAddress).approve(
        //     fluentUSDPlusAddress,
        //     type(uint256).max
        // );

        fedMemberId = _fedMemberId;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    ///       REMOVE IT =P
    // function renewApproval() external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     IERC20(fluentUSDPlusAddress).approve(
    //         fluentUSDPlusAddress,
    //         type(uint256).max
    //     );
    // }

    function requestRedeem(uint256 _amount, bytes32 _refId)
        public
        onlyRole(USER_ROLE)
        whenNotPaused
        returns (bool isRequestPlaced)
    {
        require(
            IERC20(fluentUSDPlusAddress).balanceOf(msg.sender) >= _amount,
            "NOT_ENOUGH_BALANCE"
        );
        require(
            IERC20(fluentUSDPlusAddress).allowance(msg.sender, address(this)) >=
                _amount,
            "NOT_ENOUGH_ALLOWANCE"
        );

        BurnTicket memory ticket;

        require(
            !ticket.status,
            "ALREADY_USED_REFID"
        );
        ticket.refId = _refId;
        ticket.from = msg.sender;
        ticket.amount = _amount;
        ticket.placedBlock = block.number;
        ticket.status = true;
        ticket.approved = false;

        _refIds.push(_refId);
        burnTickets[_refId] = ticket;

        IERC20(fluentUSDPlusAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        return true;
    }

    function approveTicket(bytes32 _refId) 
    public
    onlyRole(APPROVER_ROLE)
    whenNotPaused
    returns (bool isTicketApproved) {

        BurnTicket storage ticket = burnTickets[_refId];

        require(ticket.status, "INVALID_TICKED_ID");
        require(!ticket.approved, "TICKED_ALREADY_APPROVED");

        ticket.approved = true;

        IFluentUSDPlus(fluentUSDPlusAddress).requestBurnUSDPlus(
            ticket.refId,
            address(this),
            ticket.from,
            fedMemberId,
            ticket.amount
        );

        /// TODO: Approve or Increase Allowance
        ///       REMOVE IT =P
        // IERC20(fluentUSDPlusAddress).approve(
        //     fluentUSDPlusAddress,
        //     ticket.amount
        // );

        return true;
    }
    
    /// @notice Burn the amount of USD+ defined in the ticket
    /// @dev 
    /// @param _refId Burn TicketID
    /// @return isAmountBurned confirmation if Function gets to the end without revert
    function executeBurn(
        bytes32 _refId
    ) public onlyRole(BURNER_ROLE) whenNotPaused returns (bool isAmountBurned) {

        BurnTicket storage ticket = burnTickets[_refId];

        require(ticket.status, "TICKET_NOT_EXISTS");
        require(!ticket.burned, "BURN_ALREADY_EXECUTED");

        IFluentUSDPlus(fluentUSDPlusAddress).burn(ticket.amount);
        ticket.burned = true;

        return true;
    }

    /// @notice Returns a Burn ticket structure
    /// @dev
    /// @param _refId The Ticket Id generated in Core Banking System
    function getBurnReceiptById(bytes32 _refId)
        public
        view
        returns (BurnTicket memory)
    {
        return burnTickets[_refId];
    }

    /// @notice Returns Status, Execution Status and the Block Number when the burn occurs
    /// @dev
    /// @param _refId The Ticket Id generated in Core Banking System
    function getBurnStatusById(bytes32 _refId)
        public
        view
        returns (
            bool,
            bool,
            bool,
            uint256
        )
    {
        if (burnTickets[_refId].status) {
            return (
                burnTickets[_refId].status,
                burnTickets[_refId].approved,
                burnTickets[_refId].burned,
                burnTickets[_refId].confirmedBlock
            );
        } else {
            return (false, false, false, 0);
        }
    }
}