// SPDX-License-Identifier: MIT
// Developer: @Brougkr
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import './IGTICWhitelist.sol';
import './IArtBlocks.sol';

contract ICCMint is Pausable
{   
    address private immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;                                    
    address private immutable _ArtBlocksMintingContractAddress = 0x58727f5Fc3705C30C9aDC2bcCC787AB2BA24c441;
    address private immutable _ArtBlocksCoreContractAddress = 0x1CD623a86751d4C4f20c96000FEC763941f098A2;
    address private immutable _GTICWhitelistContractAddress = 0xDF6D84c56074158888CA3db041630c5FB4F76710;
    uint256 private immutable _ArtBlocksProjectID = 121;
    address private immutable owner = 0x5de8D267Ae890589b45146b92BA5b41eA424526B; // "fake" venice ipad (change to spec) 

    //Purchases NFT to address
    function purchaseTo(uint256 ticketTokenID) public
    {
        require(msg.sender == owner);

        //This Queries the IGTICWhitelist Contract & ensures that the address being whitelisted is the one that is being purchased to
        if(msg.sender == owner)
        {
            address to = IGTICWhitelist(_GTICWhitelistContractAddress).readWhitelist(ticketTokenID);
            approveBRT();
            uint256 tokenID = mintArtBlocks();
            sendTo(to, tokenID);
        } 
    }

    //Step 1: Approves BRT for spending on ArtBlocks Contract
    function approveBRT() private 
    { 
        require(msg.sender == owner);
        if(msg.sender == owner)
        {
            IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, 1000000000000000000); 
        }
    }

    //Step 2: Mints ICC
    function mintArtBlocks() private returns (uint tokenID) 
    { 
        require(msg.sender == owner);
        if(msg.sender == owner)
        {
            return IArtblocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); 
        }
    }

    //Step 3: Sends tokenID to the "to" address specified
    function sendTo(address to, uint256 tokenID) private 
    {   
        require(msg.sender == owner);
        if(msg.sender == owner)
        {
            IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); 
        }
    }

    //Optional: Withdraws Extra Tokens / Ether
    function withdraw() public 
    { 
        require(msg.sender == owner);
        if(msg.sender == owner)
        {
            payable(msg.sender).transfer(address(this).balance); 
        }
    }
}