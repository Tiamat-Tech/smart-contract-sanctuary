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
import './IGoldenTicket.sol';

contract ICCMint is Ownable, Pausable
{   
    address public immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;  //Bright Moments BRT Address                                      
    address public immutable _ArtBlocksTokenAddress = 0x58727f5Fc3705C30C9aDC2bcCC787AB2BA24c441;   //ArtBlocks Address
    uint public immutable _ArtBlocksProjectID = 121;                                                //ArtBlocks Project ID

    function mintArtBlocks() public onlyOwner returns (uint)
    {
        // IArtblocks(_ArtBlocksTokenAddress).purchase{value: 0.1 ether}(_ArtBlocksProjectID);
        IArtblocks(_ArtBlocksTokenAddress).purchase(_ArtBlocksProjectID);
    }

    function sendTo(address to, uint tokenID) public onlyOwner
    {
        IERC721(_ArtBlocksTokenAddress).safeTransferFrom(msg.sender, to, tokenID);
    }

    function purchaseTo(address to) public onlyOwner
    {
        approveBRT();
        uint x = mintArtBlocks();
        sendTo(to, x);
    }

    function approveBRT() public onlyOwner { _approveBRT(_ArtBlocksTokenAddress); }

    function _approveBRT(address to) private { IERC20(_ERC20_BRT_TokenAddress).approve(to, 10000000000000000000); }
}