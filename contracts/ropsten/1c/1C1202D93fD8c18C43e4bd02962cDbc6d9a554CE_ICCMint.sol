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
    address public immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;  //Bright Moments BRT Address                                      
    address public immutable _ArtBlocksTokenAddress = 0x58727f5Fc3705C30C9aDC2bcCC787AB2BA24c441;   //ArtBlocks Address
    uint public immutable _ArtBlocksProjectID = 121;                                                //ArtBlocks Project ID

    //Purchases NFT to address
    function purchaseTo(address to) public onlyOwner
    {
        approveBRT();
        uint tokenID = mintArtBlocks();
        sendTo(to, tokenID);
    }

    //Mints ICC
    function mintArtBlocks() private onlyOwner returns (uint tokenID)
    {
        // IArtblocks(_ArtBlocksTokenAddress).purchase{value: 0.1 ether}(_ArtBlocksProjectID); //for ether tests
        return IArtblocks(_ArtBlocksTokenAddress).purchase(_ArtBlocksProjectID); //for brt tests
    }

    //Sends tokenID to the "to" address specified
    function sendTo(address to, uint tokenID) private onlyOwner 
    { 
        IERC721(_ArtBlocksTokenAddress).safeTransferFrom(address(this), to, tokenID); 
    }

    //Approves BRT for spending on ArtBlocks Contract
    function approveBRT() private 
    { 
        IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksTokenAddress, 1000000000000000000); 
    }
}