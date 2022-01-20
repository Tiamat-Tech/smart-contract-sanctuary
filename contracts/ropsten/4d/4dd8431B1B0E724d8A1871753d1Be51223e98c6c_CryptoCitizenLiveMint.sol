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
    address private immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;             // BRTDE Contract Address   
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;                        // Bright Moments Multisig Address    
    address private immutable _ArtBlocksMintingContractAddress = 0x24CCA47Fcc4fe09b51aBE8A8124C3da01765bE14;    // ArtBlocks Minting Contract
    address private immutable _ArtBlocksCoreContractAddress = 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;       // Artblocks NFT Collection Contract
    address private immutable _GoldenTicketAddress = 0x8b68b0d0BFE370F9cb6f0107a6F1b8B1372De8ba;                // Golden Token Address
    uint256 private immutable _ArtBlocksProjectID = 0;                                                          // ArtBlocks Project ID
    bytes32 private immutable _MINTER_ROLE = keccak256("MINTER_ROLE");                                          // Minter Role
    bytes32 private immutable _DELISTED_ROLE = keccak256("DELISTED_ROLE");                                      // Delisted Role
    mapping (address => bytes32) private role;
    mapping (uint256 => address) private mintingWhitelist;
    mapping (uint256 => bool) private minted; 
    
    // Pre-Approves 1000 BRT For Purchasing (denoted in WEI)
    constructor() 
    { 
        approveBRT(10000000); // Approves 10,000,000 BRT for Minting
        role[0x2596a3df23725F1F2DfaDAf4a132175165aB6744] = _MINTER_ROLE;
        transferOwnership(_BRTMULTISIG);
    }

    // Sends Golden Ticket & Whitelists Address to receive CryptoCitizen
    function _whitelistGT(uint256 ticketTokenID) public nonReentrant
    {
        require(IERC721(_GoldenTicketAddress).ownerOf(ticketTokenID) == msg.sender, "Sender Does Not Own Ticket With The Input Token ID");
        IERC721(_GoldenTicketAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, ticketTokenID);
        mintingWhitelist[ticketTokenID] = msg.sender;
    }

    // Mints NFT to address
    function _LiveMint(uint256 ticketTokenID) public nonReentrant
    {
        requireMinter();
        address to = readWhitelist(ticketTokenID);
        require(to != address(0), "Golden Ticket Entered Is Not Whitelisted");
        require(!minted[ticketTokenID], "Golden Ticket Already Minted");
        uint256 tokenID = mintArtBlocks();
        sendTo(to, tokenID);
        minted[ticketTokenID] = true;
    }

    // Step 1: Approves BRT for spending on ArtBlocks Contract (denoted in wei)
    function approveBRT(uint256 amount) public onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    // Step 2: Mints CryptoCitizen NFT
    function mintArtBlocks() private returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); }

    // Step 3: Sends tokenID to the "to" address specified
    function sendTo(address to, uint256 tokenID) private { IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); }

    // Withdraws ERC20 Tokens to Multisig
    function withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
    }

    // Grants Address Minter Role
    function addMinter(address minter) public onlyOwner { role[minter] = _MINTER_ROLE; }

    // De-Lists Minter
    function removeMinter(address minter) public onlyOwner { role[minter] = _DELISTED_ROLE; }

    // Withdraws Ether to Multisig
    function withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }

    // Checks If User Is Valid BRT Minter
    function requireMinter() private view { require(role[msg.sender] == _MINTER_ROLE, "USER IS NOT VALID BRT MINTER"); }

    // Reads Whitelisted Address Corresponding to GoldenTicket TokenID
    function readWhitelist(uint256 tokenID) public view returns(address) { return mintingWhitelist[tokenID]; }
}