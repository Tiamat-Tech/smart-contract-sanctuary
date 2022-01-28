// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity 0.8.10;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CryptoCitizenGovernanceTicketSale is Ownable, Pausable, ReentrancyGuard
{
    //Ticket Token Address
    address public _TICKET_TOKEN_ADDRESS = 0xc880AF524B8a1cF349f2C6DBF99195D0837Bf08f;
    address public _BRT_MULTISIG = 0x2596a3df23725F1F2DfaDAf4a132175165aB6744;

    //Token Amounts
    uint256 public _TICKETS_MINTED = 1;
    uint256 public _MAX_TICKETS = 50;
    
    //Price
    uint256 public _TICKET_PRICE = 0.01 ether; //change to spec

    //Sale State
    bool public _SALE_IS_ACTIVE = false;

    //Mint Mapping
    mapping (address => bool) private minted;
    mapping (address => uint256) public whitelist;

    //Events
    event WhitelistClaimed(address indexed recipient, uint indexed amt);

    constructor() {}

    //Purchases CryptoCitizenGovernanceTicketSale Tickets
    function TicketMint(uint numberOfTokens) public payable nonReentrant
    {
        require(_SALE_IS_ACTIVE, "Sale must be active to mint Tickets");
        require(whitelist[msg.sender] > 0 && numberOfTokens <= whitelist[msg.sender], "Ticket Amount Exceeds `msg.sender` Allowance");
        require(_TICKETS_MINTED + numberOfTokens <= _MAX_TICKETS, "Purchase Would Exceed Max Supply Of Tickets");
        require(_TICKET_PRICE * numberOfTokens == msg.value, "Ether Value Sent Is Not Correct. 0.01 ETH Per Ticket | 1000000000000000 WEI");
        require(!minted[msg.sender], "Address Has Already Minted");
        whitelist[msg.sender] -= numberOfTokens;
 
        //Purchases Tickets
        for(uint i = 0; i < numberOfTokens; i++) 
        {
            IERC721(_TICKET_TOKEN_ADDRESS).transferFrom(_BRT_MULTISIG, msg.sender, _TICKETS_MINTED);
            _TICKETS_MINTED += 1;
        }
        
        minted[msg.sender] = true;
        emit WhitelistClaimed(msg.sender, numberOfTokens);
    }

    //Adds Airdrop Recipients To Airdrop Whitelist
    function __addAirdropRecipients(address[] calldata wallets, uint256[] calldata amounts) external onlyOwner
    {
        for(uint i = 0; i < wallets.length; i++)
        {
            whitelist[wallets[i]] = amounts[i];
        }
    }

    //Sets Future Ticket Price
    function __setTicketPrice(uint256 TICKET_PRICE) public onlyOwner { _TICKET_PRICE = TICKET_PRICE; }
    
    //Flips Sale State
    function __flip_saleState() public onlyOwner { _SALE_IS_ACTIVE = !_SALE_IS_ACTIVE; }

    //Withdraws Ether from Contract
    function __withdraw() public onlyOwner { payable(msg.sender).transfer(address(this).balance); }

    //Pauses Contract
    function __pause() public onlyOwner { _pause(); }

    //Unpauses Contract
    function __unpause() public onlyOwner { _unpause(); }
}