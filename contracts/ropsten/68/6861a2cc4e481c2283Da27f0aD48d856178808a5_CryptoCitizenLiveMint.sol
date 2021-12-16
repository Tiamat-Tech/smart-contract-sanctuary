// SPDX-License-Identifier: MIT
// Developer: @Brougkr
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IGoldenTicketWhitelist.sol';
import './IArtBlocks.sol';

contract CryptoCitizenLiveMint is Ownable, Pausable
{   
    address private immutable _ERC20_BRT_TokenAddress = 0x7Fee6e7FAf98af42eb83f3aA882d99D3D6aD4940;             //BRTNY Mainnet Contract Address   
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;                        //Bright Moments Multisig Mainnet Address    
    address private immutable _ArtBlocksMintingContractAddress = 0x47e312d99C09Ce61A866c83cBbbbED5A4b9d33E7;    //ArtBlocks Minting Contract
    address private immutable _ArtBlocksCoreContractAddress = 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;       //Artblocks NFT Collection Contract
    address private immutable _GoldenTicketWhitelistContractAddress = address(0);                               //DEPLOY WHITELIST FIRST
    uint256 private immutable _ArtBlocksProjectID = 189;                                                        //CNY ArtBlocks Project ID

    //Purchases NFT to address
    function purchaseTo(uint256 ticketTokenID) public onlyOwner
    {
        address to = IGoldenTicketWhitelist(_GoldenTicketWhitelistContractAddress).readWhitelist(ticketTokenID);
        uint256 tokenID = mintArtBlocks();
        sendTo(to, tokenID);
    }

    //Step 1: Approves BRT for spending on ArtBlocks Contract (denoted in wei)
    function approveBRT(uint256 amount) private onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    //Step 2: Mints CryptoCitizen NFT
    function mintArtBlocks() private onlyOwner returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); } //testnet
    // function mintArtBlocks() private onlyOwner returns (uint tokenID) { return IArtBlocksMainnet(_ArtBlocksMintingContractAddress).mint(); } //mainnet

    //Step 3: Sends tokenID to the "to" address specified
    function sendTo(address to, uint256 tokenID) private onlyOwner { IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); }

    //Withdraws ERC20 Tokens to Multisig
    function withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        if(erc20Token.balanceOf(address(this)) > 0)
        {
            erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
        }
    }  

    //Withdraws Ether to Multisig
    function withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }
}