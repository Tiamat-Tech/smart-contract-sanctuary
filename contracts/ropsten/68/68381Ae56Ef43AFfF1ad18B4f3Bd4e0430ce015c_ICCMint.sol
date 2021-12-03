// SPDX-License-Identifier: MIT
// Developer: @Brougkr
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import './IArtBlocks.sol';

contract ICCMint is Ownable, Pausable
{   
    address public immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;                                    
    address public immutable _ArtBlocksMintingContractAddress = 0x58727f5Fc3705C30C9aDC2bcCC787AB2BA24c441;
    address public immutable _ArtBlocksCoreContractAddress = 0x1CD623a86751d4C4f20c96000FEC763941f098A2;
    uint public immutable _ArtBlocksProjectID = 121;                                                            

    //Purchases NFT to address
    function purchaseTo(address to) public onlyOwner
    {
        approveBRT();
        uint tokenID = mintArtBlocks();
        approveNFT(tokenID);
        sendTo(to, tokenID);
    }

    //Mints ICC
    function mintArtBlocks() public onlyOwner returns (uint tokenID)
    {
        // IArtblocks(_ArtBlocksMintingContractAddress).purchase{value: 0.1 ether}(_ArtBlocksProjectID); //for ether tests
        return IArtblocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); //for brt tests
    }

    //Sends tokenID to the "to" address specified
    function sendTo(address to, uint tokenID) public onlyOwner 
    { 
        IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); 
    }

    //Approves BRT for spending on ArtBlocks Contract
    function approveBRT() public onlyOwner
    { 
        IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, 1000000000000000000); 
    }

    function approveNFT(uint tokenID) public onlyOwner
    {
        // IArtBlocksCore(_ArtBlocksCoreContractAddress).approve(msg.sender, tokenID);
    }
}