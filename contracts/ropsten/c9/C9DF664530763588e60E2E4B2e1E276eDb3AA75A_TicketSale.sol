// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity 0.8.10;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TicketSale is Ownable, Pausable, ReentrancyGuard
{
    // Addresses
    address public _TICKET_TOKEN_ADDRESS = 0x8d54Ff0E333c8Ff188fE437AA37999234d4D8D65;
    address public _BRT_MULTISIG = 0x2596a3df23725F1F2DfaDAf4a132175165aB6744;

    // Token Amounts
    // uint256 public _TICKET_INDEX = 50;
    // uint256 public _MAX_TICKETS = 100;
    uint256 public _TICKET_INDEX = 0;
    uint256 public _MAX_TICKETS = 100;
    
    // Price
    uint256 public _TICKET_PRICE_BRIGHT_LIST = 0.1 ether;
    uint256 public _TICKET_PRICE_PUBLIC = 0.2 ether;

    // Sale State
    bool public _PUBLIC_SALE_IS_ACTIVE = true;
    bool public _BRIGHT_SALE_IS_ACTIVE = true;
    bool public _ALLOW_MULTIPLE_PURCHASES = true;

    // Mint Mapping
    mapping (address => bool) public purchased;
    mapping (address => uint256) public BrightList;

    // Events
    event TicketPurchased(address indexed recipient, uint256 indexed amt, uint256 indexed ticketID);
    event GovernanceRecipientsAdded(address[] wallets, uint256[] amounts);

    constructor() { }

    function TicketPurchase() public payable nonReentrant whenNotPaused
    {
        require(_BRIGHT_SALE_IS_ACTIVE || _PUBLIC_SALE_IS_ACTIVE, "No Sale Active");
        require(_TICKET_INDEX + 1 < _MAX_TICKETS, "Purchase Would Exceed Max Supply Of Tickets");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!purchased[msg.sender], "Address Has Already Purchased"); }

        if(_BRIGHT_SALE_IS_ACTIVE && BrightList[msg.sender] > 0)
        {
            require(_TICKET_PRICE_BRIGHT_LIST == msg.value, "Ether Value Sent Is Not Correct. Bright Sale is 1 ETH Per Ticket");
            BrightList[msg.sender] -= 1;
            IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKET_INDEX);
            _TICKET_INDEX += 1;
            purchased[msg.sender] = true;
            emit TicketPurchased(msg.sender, 1, _TICKET_INDEX);
        }
        else
        {
            require(_TICKET_PRICE_PUBLIC == msg.value, "Ether Value Sent Is Not Correct. Public Sale is 2 ETH Per Ticket");
            IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKET_INDEX);
            _TICKET_INDEX += 1;
            purchased[msg.sender] = true;
            emit TicketPurchased(msg.sender, 1, _TICKET_INDEX);
        }
    }

    // Purchases London Ticket
    function BrightListTicketPurchase() public payable nonReentrant whenNotPaused
    {
        require(_BRIGHT_SALE_IS_ACTIVE, "Sale must be active to mint Tickets");
        require(BrightList[msg.sender] > 0, "Ticket Amount Exceeds `msg.sender` Allowance");
        require(_TICKET_INDEX + 1 < _MAX_TICKETS, "Purchase Would Exceed Max Supply Of Tickets");
        require(_TICKET_PRICE_BRIGHT_LIST == msg.value, "Ether Value Sent Is Not Correct. 1 ETH Per Ticket");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!purchased[msg.sender], "Address Has Already Purchased"); }
        BrightList[msg.sender] -= 1;
        IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKET_INDEX);
        _TICKET_INDEX += 1;
        purchased[msg.sender] = true;
        emit TicketPurchased(msg.sender, 1, _TICKET_INDEX);
    }

    // Purchases London Ticket
    function PublicTicketPurchase() public payable nonReentrant whenNotPaused
    {
        require(_PUBLIC_SALE_IS_ACTIVE, "Sale must be active to mint Tickets");
        require(_TICKET_INDEX + 1 < _MAX_TICKETS, "Purchase Would Exceed Max Supply Of Tickets");
        require(_TICKET_PRICE_PUBLIC == msg.value, "Ether Value Sent Is Not Correct. 1 ETH Per Ticket");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!purchased[msg.sender], "Address Has Already Purchased"); }
        IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKET_INDEX);
        _TICKET_INDEX += 1;
        purchased[msg.sender] = true;
        emit TicketPurchased(msg.sender, 1, _TICKET_INDEX);
    }

    // Adds Governance Recipients To BrightList Purchase List
    function __addGovernanceRecipients(address[] calldata wallets, uint256[] calldata amounts) external onlyOwner
    {
        for(uint i = 0; i < wallets.length; i++)
        {
            BrightList[wallets[i]] = amounts[i];
        }
        emit GovernanceRecipientsAdded(wallets, amounts);
    }

    // Sets Ticket Price
    function __setBrightTicketPrice(uint256 TICKET_PRICE) external onlyOwner { _TICKET_PRICE_BRIGHT_LIST = TICKET_PRICE; }

    // Sets Ticket Price
    function __setPublicTicketPrice(uint256 TICKET_PRICE) external onlyOwner { _TICKET_PRICE_PUBLIC = TICKET_PRICE; }

    // Sets Max Tickets
    function __setTicketAllocation(uint256 MAX_TICKETS) external onlyOwner { _MAX_TICKETS = MAX_TICKETS; }

    // Overrides Ticket Index
    function __setTicketIndex(uint256 TICKET_INDEX) external onlyOwner { _TICKET_INDEX = TICKET_INDEX; }
    
    // Flips BrightList Sale State
    function __flipBrightSaleState() external onlyOwner { _BRIGHT_SALE_IS_ACTIVE = !_BRIGHT_SALE_IS_ACTIVE; }

    // Flips Public Sale State
    function __flipPublicSaleState() external onlyOwner { _PUBLIC_SALE_IS_ACTIVE = !_PUBLIC_SALE_IS_ACTIVE; }

    // Flips Multiple Purchases
    function __flipMultiplePurchases() external onlyOwner { _ALLOW_MULTIPLE_PURCHASES = !_ALLOW_MULTIPLE_PURCHASES; }

    // Pauses Contract
    function __pauseContract() external onlyOwner { _pause(); }

    // Unpauses Contract
    function __unpauseContract() external onlyOwner { _unpause(); }
    
    // Withdraws Ether from Contract
    function __withdrawEther() external onlyOwner { payable(_BRT_MULTISIG).transfer(address(this).balance); }

    // Withdraws ERC-20 from Contract
    function __withdrawERC20(address contractAddress) external onlyOwner 
    { 
        IERC20 ERC20 = IERC20(contractAddress); 
        uint256 balance = ERC20.balanceOf(address(this));
        ERC20.transferFrom(address(this), _BRT_MULTISIG, balance); 
    }
}