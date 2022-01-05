// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IComplianceManager {
    function checkWhiteList(address _addr) external view returns (bool);
    function checkBlackList(address _addr) external view returns (bool);
}

//TODO: Create and emit events (@dev)

/// @title USD+ Token Contract
/// @author Fluent Group - Development team
/// @notice Stable coin backed in USD Dolars
/// @dev This is a standard ERC20 with Pause, Mint/Burn and Access Control features
contract USDPlus is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");

    /// @notice 5760 number of blocks mined per day
    uint256 EXPIRATION_TIME = 5760;

    ///@dev set a number higher than 0 to enable multisig
    uint8 numConfirmationsRequired = 0;

    struct MintTicket {
        bytes32 ID;
        address from;
        address to;
        uint256 amount;
        uint256 placedBlock;
        uint256 confirmedBlock;
        bool status;
        bool executed;
    }
    mapping(bytes32 => address[]) approvalChain;

    mapping(bytes32 => MintTicket) mintTickets;
    bytes32[] public ticketsIDs;

    mapping(bytes32 => bool) usedIDs;
    mapping(bytes32 => mapping(address => bool)) public isConfirmed;

    address complianceManagerAddr;

    modifier ticketExists(bytes32 _ID) {
        require(usedIDs[_ID], "TICKET_NOT_EXISTS");
        _;
    }

    modifier notConfirmed(bytes32 _ID) {
        require(!isConfirmed[_ID][msg.sender], "TICKET_ALREADY_CONFIRMED");
        _;
    }

    modifier notExecuted(bytes32 _ID) {
        MintTicket storage ticket = mintTickets[_ID];
        require(!ticket.executed, "TICKET_ALREADY_EXECUTED");
        _;
    }

    modifier notExpired(bytes32 _ID) {
        MintTicket storage ticket = mintTickets[_ID];
        uint256 ticketValidTime = ticket.placedBlock + EXPIRATION_TIME;
        require(block.number < ticketValidTime, "TICKET_HAS_EXPIRED");
        _;
    }

    constructor() ERC20("USD Plus", "USD+") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function decimals() public pure override(ERC20) returns (uint8) {
        return 6;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // missing implementation with Compliance List
    function requestMint(
        bytes32 _ID,
        uint256 _amount,
        address _to
    ) public onlyRole(REQUESTER_ROLE) whenNotPaused {
        require(!usedIDs[_ID], "INVALID_ID");
        require(!_getCheckBlackList(_to) == true, "Address blacklisted");

        MintTicket memory ticket;

        ticket.ID = _ID;
        ticket.from = msg.sender;
        ticket.to = _to;
        ticket.amount = _amount;
        ticket.placedBlock = block.number;
        ticket.status = true;
        ticket.executed = false;

        ticketsIDs.push(_ID);
        mintTickets[_ID] = ticket;

        usedIDs[_ID] = true;
    }

    function confirmMintTicket(bytes32 _ID)
        public
        onlyRole(APPROVER_ROLE)
        whenNotPaused
        ticketExists(_ID)
        notExecuted(_ID)
        notConfirmed(_ID)
        notExpired(_ID)
    {
        MintTicket storage ticket = mintTickets[_ID];
        require(msg.sender != ticket.from, "REQUESTER_CANT_APPROVE");

        isConfirmed[_ID][msg.sender] = true;
        approvalChain[_ID].push(msg.sender);
    }

    function mint(bytes32 _ID)
        public
        onlyRole(MINTER_ROLE)
        whenNotPaused
        ticketExists(_ID)
        notExecuted(_ID)
        notExpired(_ID)
    {
        MintTicket storage ticket = mintTickets[_ID];

        require(
            approvalChain[_ID].length >= numConfirmationsRequired,
            "NOT_ENOUGH_CONFIRMATIONS"
        );
        ticket.executed = true;
        ticket.confirmedBlock = block.number;

        _mint(ticket.to, ticket.amount);
    }

    function setNumConfirmationsRequired(uint8 numOfConfirmations)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        numConfirmationsRequired = numOfConfirmations;
    }

    function getReceiptById(bytes32 _ID)
        public
        view
        returns (MintTicket memory)
    {
        return mintTickets[_ID];
    }

    function getStatusById(bytes32 _ID)
        public
        view
        returns (bool, bool)
    {
        return (mintTickets[_ID].status, mintTickets[_ID].executed);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function setComplianceManagerAddr(address _complianceManagerAddr)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        complianceManagerAddr = _complianceManagerAddr;
    }

    function _getCheckWhiteList(address _addr) internal view returns (bool) {
        require(complianceManagerAddr != address(0), "COMPLIANCE_MNGR_NOT_SET");

        return IComplianceManager(complianceManagerAddr).checkWhiteList(_addr);
    }

    function _getCheckBlackList(address _addr) internal view returns (bool) {
        require(complianceManagerAddr != address(0), "COMPLIANCE_MNGR_NOT_SET");

        return IComplianceManager(complianceManagerAddr).checkBlackList(_addr);
    }
}