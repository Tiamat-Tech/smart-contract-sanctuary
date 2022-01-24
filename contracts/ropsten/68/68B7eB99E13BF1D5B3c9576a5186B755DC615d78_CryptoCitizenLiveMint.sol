// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity 0.8.10;
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './IArtBlocks.sol';

contract CryptoCitizenLiveMint is Ownable, Pausable, ReentrancyGuard
{   
    /* --- PRIVATE IMMUTABLES --- */
    address private immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;             // BRT Contract Address   
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;                        // Bright Moments Multisig Contract Address    
    address private immutable _ArtBlocksMintingContractAddress = 0x296FF13607C80b550dd136435983734c889Ccca4;    // ArtBlocks Minting Contract Address
    address private immutable _ArtBlocksCoreContractAddress = 0x24CCA47Fcc4fe09b51aBE8A8124C3da01765bE14;       // Artblocks NFT Collection Contract Address
    address private immutable _GoldenTicketAddress = 0x8b68b0d0BFE370F9cb6f0107a6F1b8B1372De8ba;                // Golden Token Contract Address
    uint256 private immutable _ArtBlocksProjectID = 0;                                                          // ArtBlocks Project ID
    bytes32 private immutable _MINTER_ROLE = keccak256("MINTER_ROLE");                                          // Minter Role
    bytes32 private immutable _DEACTIVATED_ROLE = keccak256("DELISTED_ROLE");                                   // Deactivates Role

    /* --- MAPPINGS --- */
    mapping (address => uint256) public userSelectedSlot;
    mapping (uint256 => address) public ticketCheckedIn;
    mapping (uint256 => address) public mintingWhitelist;
    mapping (address => bytes32) private role;
    mapping (uint256 => uint256) private bookings;
    mapping (uint256 => bool) private minted; 

    /* --- EVENTS --- */
    event MintComplete(address indexed redeemer, uint256 indexed ticketTokenID, uint256 indexed citizenTokenID);
    event GoldenTokenRedeemed(address indexed redeemer, uint256 indexed ticketTokenID, uint256 slotClaimed);
    event GoldenTokenUnRedeemed(address indexed redeemer, uint256 indexed ticketTokenID, uint256 slotOpened);
    event TicketRedeemerTimeslotChange(address indexed redeemer, uint256 slot);

    // Constructor Pre-Approves 1000 BRT For Purchasing (denoted in WEI), Grants Initial Minter Roles, & Transfers Ownership to Multisig
    constructor() 
    { 
        __approveBRT(10000000);
        role[0x5778B0B140Fa7a62B96c193cC8621e6E96c088A5] = _MINTER_ROLE; // BRT Minter #1
        role[0x0000000000000000000000000000000000000000] = _MINTER_ROLE; // BRT Minter #2
        role[0x0000000000000000000000000000000000000000] = _MINTER_ROLE; // BRT Minter #3
        role[0x0000000000000000000000000000000000000000] = _MINTER_ROLE; // BRT Minter #4
        transferOwnership(_BRTMULTISIG);
    }

    /*-------------------*/
    /*  PUBLIC FUNCTIONS */
    /*-------------------*/

    // Redeems Golden Ticket & Whitelists Address To Receive CryptoCitizen
    function RedeemGT(uint256 ticketTokenID, uint256 slot) public nonReentrant whenNotPaused
    {
        require(IERC721(_GoldenTicketAddress).ownerOf(ticketTokenID) == msg.sender, "Sender Does Not Own Ticket With The Input Token ID");
        require(bookings[slot] > 0, "This Booking Time Has Already Been Fully Reserved, Or Is Not A Valid Slot");
        IERC721(_GoldenTicketAddress).transferFrom(msg.sender, _BRTMULTISIG, ticketTokenID);
        mintingWhitelist[ticketTokenID] = msg.sender;
        userSelectedSlot[msg.sender] = slot;
        bookings[slot] -= 1;
        emit GoldenTokenRedeemed(msg.sender, ticketTokenID, userSelectedSlot[msg.sender]);
    }

    // Un-Redeems Golden Ticket & Refunds The User Their Ticket
    function UnRedeemGT(uint256 ticketTokenID) public nonReentrant whenNotPaused
    {
        require(mintingWhitelist[ticketTokenID] == msg.sender, "Sender Has Not Redeemed Golden Token With The Input TokenID");
        require(!minted[ticketTokenID], "Ticket Has Been Redeemed & Minted & Is No Longer Valid");
        mintingWhitelist[ticketTokenID] = address(0);
        uint256 slot = userSelectedSlot[msg.sender];
        bookings[slot] += 1;
        userSelectedSlot[msg.sender] = 0;
        IERC721(_GoldenTicketAddress).transferFrom(_BRTMULTISIG, msg.sender, ticketTokenID);
        emit GoldenTokenUnRedeemed(msg.sender, ticketTokenID, slot);
    }

    // Allows User To Change Their Desired Minting Timeslot
    function ChangeTimeslot(uint256 ticketTokenID, uint256 slot) public nonReentrant whenNotPaused
    {
        require(mintingWhitelist[ticketTokenID] == msg.sender, "Sender Has Not Redeemed Golden Token With The Input TokenID");
        require(!minted[ticketTokenID], "Ticket Has Been Redeemed & Minted & Is No Longer Valid");
        require(bookings[slot] > 0, "This Booking Time Has Already Been Fully Reserved, Or Is Not A Valid Slot");
        bookings[userSelectedSlot[msg.sender]] += 1;
        userSelectedSlot[msg.sender] = slot;
        emit TicketRedeemerTimeslotChange(msg.sender, slot);
    }

    /*-------------------*/
    /*     BRT STAFF     */
    /*-------------------*/

    // Mints NFT to address
    function _IRLMint(uint256 ticketTokenID) public onlyMinter whenNotPaused 
    {
        address to = readWhitelist(ticketTokenID);
        require(to != address(0), "Golden Ticket Entered Is Not Whitelisted");
        require(!minted[ticketTokenID], "Golden Ticket Already Minted");
        uint256 citizenTokenID = mintArtBlocks();
        minted[ticketTokenID] = true;
        sendTo(to, citizenTokenID);
        emit MintComplete(to, ticketTokenID, citizenTokenID);
    }

    /*-------------------*/
    /* PRIVATE FUNCTIONS */
    /*-------------------*/

    // Mints CryptoCitizen NFT
    function mintArtBlocks() private returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); }

    // Sends Crypto Citizen corresponding to the tokenID to the "to" address specified
    function sendTo(address to, uint256 tokenID) private { IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); }

    /*-------------------*/
    /*  ADMIN FUNCTIONS  */
    /*-------------------*/

    // Adds Calendar Slot Amounts
    function __modifySlots(uint256[] calldata slots, uint256[] calldata amounts) external onlyOwner
    {
        for(uint256 i = 0; i < slots.length; i++)
        {
            bookings[slots[i]] = amounts[i];
        }
    }

    // Withdraws ERC20 Tokens to Multisig
    function __withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
    }

    // Approves BRT for spending on ArtBlocks Contract (denoted in wei)
    function __approveBRT(uint256 amount) public onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    // Grants Address Minter Role
    function __addMinter(address minter) public onlyOwner { role[minter] = _MINTER_ROLE; }

    // Deactivates Minter
    function __removeMinter(address minter) public onlyOwner { role[minter] = _DEACTIVATED_ROLE; }

    // Withdraws Ether to Multisig
    function __withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }

    /*-------------------*/
    /*   VIEW FUNCTIONS  */
    /*-------------------*/

    // Returns # Of Remaining Bookings For Input Slot
    function readSlotAmt(uint256 slot) public view returns(uint256) { return bookings[slot]; }

    // Reads Whitelisted Address Corresponding to GoldenTicket TokenID
    function readWhitelist(uint256 ticketTokenID) public view returns(address) { return mintingWhitelist[ticketTokenID]; }

    // Function Modifier That Allows Only Whitelisted BRT Minters To Access
    modifier onlyMinter() 
    {
        require(role[msg.sender] == _MINTER_ROLE, "OnlyMinter: Caller Is Not Approved BRT Minter");
        _;
    }
}