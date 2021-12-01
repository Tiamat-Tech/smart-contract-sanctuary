// SPDX-License-Identifier: MIT
// Developer: @Brougkr
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import './IArtBlocks.sol';

contract LiveMint is Ownable, Pausable
{   
    address public _ERC721_GoldenTokenAddress = 0x48BaF803830ab470C1EA812f82B03107DB0C9786;     //Golden Token Address               { 0xd43529990F3FbA41Affd66C4A8Ab6C1b7292D9Dc }                                                  
    address public _ERC20_BRT_TokenAddress = 0xadd07987aC1A529EE5C97eFbe847628831a01e90;        //Bright Moments BRT Minting Address {  }                                               
    address public _BrightMomentsMultisig = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;         //Bright Moments Multisig Address    { 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937 }                                         
    address public _ArtBlocksTokenAddress = 0x296FF13607C80b550dd136435983734c889Ccca4;         //ArtBlocks Address                  { 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270 }
    address public _ArtBlocksDeployerAddress = address(0);                                      //Artblocks Deployer                 { address of ArtBlocks project contract creator }
    address private _ApproverAddress = address(0);                                              //Bright Moments Approver
    uint public _ArtBlocksProjectID = 0;                                                        //ArtBlocks Project ID
    address[] private _GoldenTokensSent;                                                        //Array of Addresses who Sent Golden Tokens to Multisig
    mapping(uint => address) public tokensSent;                                                 //Mapping of tokenIDs to OG senders
    mapping(uint => bool) public whitelist;                                                     //Token ID Whitelist
    mapping(uint => bool) public checkedIn;                                                     //Checked In To Bright Moments
    mapping(uint => bytes32) private ticketHashMap;                                             //Ticket Hashes

    //Phase 0 - VALIDATE
    function _validateApproval() public
    {
        require(msg.sender == tx.origin, "No External Contracts");

        //Approves Golden Token For Sending to Multisig
        IERC721(_ERC721_GoldenTokenAddress).setApprovalForAll(address(this), true);

        // IERC721(_ERC721_GoldenTokenAddress).approve(address(this), 0);

        //Approves BRT For Purchasing on ArtBlocks
        IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksTokenAddress, 10000000000000000000);
    }

    //Phase 1 - CHECK-IN
    function _checkIn(uint ticketTokenId) public
    {
        require(msg.sender == tx.origin, "No External Contracts");
        require(validRecipient(msg.sender, ticketTokenId), "User Does Not Own Ticket");
        require(whitelist[ticketTokenId] == true, "Golden Ticket Not Whitelisted");
        IERC721(_ERC721_GoldenTokenAddress).safeTransferFrom(msg.sender, _BrightMomentsMultisig, ticketTokenId);
        tokensSent[ticketTokenId] = msg.sender;
        _GoldenTokensSent.push(msg.sender);
        checkedIn[ticketTokenId] = true;
    }

    //Phase 2 - IRL MINT
    function _irlMint(uint ticketTokenId, bytes32 hashPassword) public
    {
        require(msg.sender == tx.origin, "No External Contracts");
        require(ticketHashMap[ticketTokenId] == hashPassword, "Hash Password Provided Is Incorrect");
        require(checkedIn[ticketTokenId] == true, "User Not Checked In");
        require(whitelist[ticketTokenId] == true, "Golden Ticket Not Whitelisted");
        IArtblocks(_ArtBlocksTokenAddress).mint(msg.sender, _ArtBlocksProjectID, _ArtBlocksDeployerAddress);
        whitelist[ticketTokenId] = false; 
    }

    //All-in-one function to perform validation, check-in, and mint
    function _wrapped(uint ticketTokenId, bytes32 hashPassword) public onlyOwner
    {
        _validateApproval();
        _checkIn(ticketTokenId);
        _irlMint(ticketTokenId, hashPassword);
    }
    
    //Sets Hash Passwords
    function change_HashPasswords(uint[] calldata tokenIDs, bytes[] memory hashPasswords) public onlyOwner
    {
        for(uint i = 0; i < tokenIDs.length; i++) 
        { 
            ticketHashMap[tokenIDs[i]] = keccak256(hashPasswords[i]);
        }
    }

    function viewGoldenTicketsSenderWallets() public view onlyOwner returns(address[] memory) { return _GoldenTokensSent; }

    function whitelistTokenID(uint tokenID) public onlyOwner { whitelist[tokenID] = true; }

    function blacklistTokenID(uint tokenID) public onlyOwner { whitelist[tokenID] = false; }

    function viewTicketHashMap(uint tokenID) public onlyOwner view returns(bytes32) { return(ticketHashMap[tokenID]); }

    function validRecipient(address to, uint ticketTokenId) public view returns (bool) { return(IERC721(_ERC721_GoldenTokenAddress).ownerOf(ticketTokenId) == to); }

    function isApprovedGT(address to) public view returns (bool) { return IERC721(_ERC721_GoldenTokenAddress).isApprovedForAll(to, address(this)); }

    function approveBRT(address to) public returns (bool) { return IERC20(_ERC20_BRT_TokenAddress).approve(to, 10000000000000000000); }

    function change_ApproverAddress(address approver) public onlyOwner { _ApproverAddress = approver; }

    function change_HashPassword(uint tokenID, bytes32 hashPassword) public onlyOwner { ticketHashMap[tokenID] = hashPassword; }

    function change_MultisigAddress(address BrightMomentsMultisig) public onlyOwner { _BrightMomentsMultisig = BrightMomentsMultisig; }

    function change_ERC721Address(address ERC721_GoldenTokenAddress) public onlyOwner { _ERC721_GoldenTokenAddress = ERC721_GoldenTokenAddress; }

    function change_ERC20Address(address ERC20_BRT_TokenAddress) public onlyOwner { _ERC20_BRT_TokenAddress = ERC20_BRT_TokenAddress; }

    function change_ArtBlocksProjectID(uint ArtBlocksProjectID) public onlyOwner { _ArtBlocksProjectID = ArtBlocksProjectID; }

    function change_ArtBlocksDeployerAddress(address ArtBlocksDeployerAddress) public onlyOwner { _ArtBlocksDeployerAddress = ArtBlocksDeployerAddress; }
}