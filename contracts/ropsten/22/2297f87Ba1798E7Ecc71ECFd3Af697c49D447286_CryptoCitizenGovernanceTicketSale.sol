// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity 0.8.10;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CryptoCitizenGovernanceTicketSale is Ownable, Pausable, ReentrancyGuard
{
    // Addresses
    address public _TICKET_TOKEN_ADDRESS = 0xC2A3c3543701009d36C0357177a62E0F6459e8A9;
    address public _BRT_MULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;

    // Token Amounts
    uint256 public _TICKET_INDEX = 50;
    uint256 public _MAX_TICKETS = 100;
    
    // Price
    uint256 public _TICKET_PRICE = 1 ether;

    // Sale State
    bool public _SALE_IS_ACTIVE = true;
    bool public _ALLOW_MULTIPLE_PURCHASES = true;

    // Mint Mapping
    mapping (address => bool) private minted;
    mapping (address => uint256) public accessList;

    // Events
    event AccessListClaimed(address indexed recipient, uint indexed amt);
    event AirdropRecipientsAdded(address[] wallets, uint256[] amounts);

    constructor() { }

    // Purchases London Ticket
    function TicketMint() public payable nonReentrant whenNotPaused
    {
        require(_SALE_IS_ACTIVE, "Sale must be active to mint Tickets");
        require(accessList[msg.sender] > 0, "Ticket Amount Exceeds `msg.sender` Allowance");
        require(_TICKET_INDEX + 1 < _MAX_TICKETS, "Purchase Would Exceed Max Supply Of Tickets");
        require(_TICKET_PRICE == msg.value, "Ether Value Sent Is Not Correct. 0.01 ETH Per Ticket | 1000000000000000 WEI");
        if(!_ALLOW_MULTIPLE_PURCHASES) { require(!minted[msg.sender], "Address Has Already Minted"); }
        accessList[msg.sender] -= 1;
        IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKET_INDEX);
        _TICKET_INDEX += 1;
        minted[msg.sender] = true;
        emit AccessListClaimed(msg.sender, 1);
    }

    // Adds Airdrop Recipients To Airdrop AccessList
    function __addAirdropRecipients(address[] calldata wallets, uint256[] calldata amounts) external onlyOwner
    {
        for(uint i = 0; i < wallets.length; i++)
        {
            accessList[wallets[i]] = amounts[i];
        }
        emit AirdropRecipientsAdded(wallets, amounts);
    }

    // Sets Future Ticket Price
    function __setTicketPrice(uint256 TICKET_PRICE) external onlyOwner { _TICKET_PRICE = TICKET_PRICE; }

    // Sets Max Tickets
    function __setMaxTickets(uint256 MAX_TICKETS) external onlyOwner { _MAX_TICKETS = MAX_TICKETS; }
    
    // Flips Sale State
    function __flip_saleState() external onlyOwner { _SALE_IS_ACTIVE = !_SALE_IS_ACTIVE; }

    // Flips Multiple Purchases
    function __flipMultiplePurchases() external onlyOwner { _ALLOW_MULTIPLE_PURCHASES = !_ALLOW_MULTIPLE_PURCHASES; }

    // Withdraws Ether from Contract
    function __withdraw() external onlyOwner { payable(_BRT_MULTISIG).transfer(address(this).balance); }

    // Pauses Contract
    function __pause() external onlyOwner { _pause(); }

    // Unpauses Contract
    function __unpause() external onlyOwner { _unpause(); }
}