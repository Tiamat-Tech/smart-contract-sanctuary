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

interface IRedeemer {
    function executeBurn(
        bytes32 _refId
    ) external;
}


//TODO: Create and emit events (@dev)

/// @title USD+ Token Contract
/// @author Fluent Group - Development team
/// @notice Stable coin backed in USD Dolars
/// @dev This is a standard ERC20 with Pause, Mint and Access Control features
/// @notice  In order to implement governance in the federation and security to the user
/// the burn and burnfrom functions had been overrided to require a BURNER_ROLE
/// no other modification has been made.
contract USDPlus is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant REQUESTER_MINTER_ROLE = keccak256("REQUESTER_MINTER_ROLE");
    bytes32 public constant REQUESTER_BURNER_ROLE = keccak256("REQUESTER_BURNER_ROLE");

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

    mapping(bytes32 => MintTicket) public mintTickets;
    bytes32[] public ticketsIDs;

    // uint256 burnCounter;

    struct BurnTicket {
        bytes32 refId;
        address redeemerContractAddress;
        address redeemerPerson;
        address fedMemberID;
        uint256 amount;
        uint256 placedBlock;
        uint256 confirmedBlock;
        bool status;
        bool executed;
    }

    mapping(bytes32 => BurnTicket) burnTickets;
    ///@dev arrays of refIds
    struct burnTicketId {
        bytes32 refId;
        address fedMemberId;
    }

    burnTicketId[] public burnTicketsIDs;

    mapping(bytes32 => bool) public usedIDs;
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

    /// @notice returns the default USD+ decimal places
    /// @return uint8 that represents the decimals
    function decimals() public pure override(ERC20) returns (uint8) {
        return 6;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /// @notice access control applied. The address that has a BURNER_ROLE can burn tokens equivalent to its balanceOf
    function burn(uint256 amount)
        public
        virtual
        override
        onlyRole(BURNER_ROLE)
    {
        _burn(_msgSender(), amount);
    }

    /// @notice access control applied. The address that has a BURNER_ROLE can burn tokens of any address
    /// as long as such address grants allowance to an address granted with a BURNER_ROLE
    function burnFrom(address account, uint256 amount)
        public
        virtual
        override
        onlyRole(BURNER_ROLE)
    {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }

    /// @notice Creates a ticket to request a amount of USD+ to mint
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
    /// @param _amount The amount of USD+ to be minted
    /// @param _to The destination address
    function requestMint(
        bytes32 _ID,
        uint256 _amount,
        address _to
    ) public onlyRole(REQUESTER_ROLE) whenNotPaused {
        require(!usedIDs[_ID], "INVALID_ID");
        require(!_isBlackListed(_to) == true, "Address blacklisted");

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

    /// @notice You can approve the ticket to mint once you have the APPROVER_ROLE
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
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

    /// @notice Mints the amount of USD+ defined in the ticket
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
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

    /// @notice Set the number of confirmations needed for multisig works
    /// @dev
    /// @param numOfConfirmations how many people should approve the mint
    function setNumConfirmationsRequired(uint8 numOfConfirmations)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        numConfirmationsRequired = numOfConfirmations;
    }

    /// @notice Returns a ticket structure
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
    function getMintReceiptById(bytes32 _ID)
        public
        view
        returns (MintTicket memory)
    {
        return mintTickets[_ID];
    }

    /// @notice Returns Status, Execution Status and the Block Number when the mint occurs
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
    function getMintStatusById(bytes32 _ID)
        public
        view
        returns (
            bool,
            bool,
            uint256
        )
    {
        if (usedIDs[_ID]) {
            return (
                mintTickets[_ID].status,
                mintTickets[_ID].executed,
                mintTickets[_ID].confirmedBlock
            );
        } else {
            return (false, false, 0);
        }
    }

    
    /// @notice Returns a Burn ticket structure
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
    function getBurnReceiptById(bytes32 _ID)
        public
        view
        returns (BurnTicket memory)
    {
        return burnTickets[_ID];
    }

    /// @notice Returns Status, Execution Status and the Block Number when the burn occurs
    /// @dev
    /// @param _ID The Ticket Id generated in Core Banking System
    function getBurnStatusById(bytes32 _ID)
        public
        view
        returns (
            bool,
            bool,
            uint256
        )
    {
        if (burnTickets[_ID].status) {
            return (
                burnTickets[_ID].status,
                burnTickets[_ID].executed,
                burnTickets[_ID].confirmedBlock
            );
        } else {
            return (false, false, 0);
        }
    }

    /// @notice Execute transferFrom Executer Acc to this contract, and open a burn Ticket
    /// @dev to match the id the fields should be (burnCounter, _refNo, _amount, msg.sender)
    /// @param _refId Ref Code provided by customer to identify this request
    /// @param _redeemerContractAddress The Federation Member´s REDEEMER contract
    /// @param _redeemerPerson The person who is requesting USD Redeem
    /// @param _fedMemberID Identification for Federation Member
    /// @param _amount The amount to be burned
    /// @return isRequestPlaced confirmation if Function gets to the end without revert
    function requestBurnUSDPlus(
        bytes32 _refId,
        address _redeemerContractAddress,
        address _redeemerPerson,
        address _fedMemberID,
        uint256 _amount
    )
        public
        onlyRole(REQUESTER_ROLE)
        whenNotPaused
        returns (bool isRequestPlaced)
    {
        require(_redeemerContractAddress == msg.sender, "INVALID_ORIGIN_CALL");

        require(balanceOf(msg.sender) >= _amount, "NOT_ENOUGH_BALANCE");

        ///@notice considering that the burn(standard) is called by the redeemer, the redeemer does not need to have allowance inside the USD+ contract.
        // require(
        //     allowance(msg.sender, address(this)) >= _amount,
        //     "NOT_ENOUGH_ALLOWANCE"
        // );

        BurnTicket memory ticket;

        require(
            _isWhiteListed(_fedMemberID), //TODO: Change for verify _fedMemberID
            "NOT_WHITELISTED"
        );

        ticket.refId = _refId;

        ticket.redeemerContractAddress = _redeemerContractAddress;
        ticket.redeemerPerson = _redeemerPerson;
        ticket.fedMemberID = _fedMemberID;
        ticket.amount = _amount;
        ticket.placedBlock = block.number;
        ticket.status = true;
        ticket.executed = false;

        burnTicketId memory bId = burnTicketId({
            refId: _refId,
            fedMemberId: _fedMemberID
        });

        burnTicketsIDs.push(bId);

        burnTickets[_refId] = ticket;

        return true;
    }

    /// @notice Burn the amount of USD+ defined in the ticket
    /// @dev Be aware that burnID is formed by a hash of (mapping.burnCounter, mapping._refNo, _amount, _redeemBy), see requestBurnUSDPlus method
    /// @param _refId Burn TicketID
    /// @param _redeemerContractAddress address from the amount get out
    /// @param _fedMemberId Federation Member ID
    /// @param _amount Burn amount requested
    /// @return isAmountBurned confirmation if Function gets to the end without revert
    function executeBurn(
        bytes32 _refId,
        address _redeemerContractAddress,
        address _fedMemberId,
        uint256 _amount
    ) public onlyRole(BURNER_ROLE) whenNotPaused returns (bool isAmountBurned) {
        BurnTicket storage ticket = burnTickets[_refId];

        require(!ticket.executed, "BURN_ALREADY_EXECUTED");
        require(_isWhiteListed(_fedMemberId), "FEDMEMBER_BLACKLISTED");

        require(ticket.status, "TICKET_NOT_EXISTS");
        require(
            ticket.redeemerContractAddress == _redeemerContractAddress,
            "WRONG_REDEEMER_CONTRACT"
        );
        require(ticket.amount == _amount, "WRONG_AMOUNT");

        ticket.executed = true;
        ticket.confirmedBlock = block.number;

        IRedeemer(ticket.redeemerContractAddress).executeBurn(_refId);
        return true;
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

    function _isWhiteListed(address _addr) internal view returns (bool) {
        require(complianceManagerAddr != address(0), "COMPLIANCE_MNGR_NOT_SET");

        return IComplianceManager(complianceManagerAddr).checkWhiteList(_addr);
    }

    function _isBlackListed(address _addr) internal view returns (bool) {
        require(complianceManagerAddr != address(0), "COMPLIANCE_MNGR_NOT_SET");

        return IComplianceManager(complianceManagerAddr).checkBlackList(_addr);
    }

    ///TODO: Create factory
    ///TODO: Create a function to call factory and deploy new instance of
    ///      Redeemer adding to it BURNER_ROLE
}