// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity ^0.8.10;
import '@openzeppelin/contracts/interfaces/IERC721Receiver.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import './IArtBlocks.sol';

contract CryptoCitizenMintPackRedeemer is Ownable, Pausable, ReentrancyGuard
{   
    address private immutable _ERC20_BRT_TokenAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;             //BRT Ropsten Contract Address   
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;                        //Bright Moments Multisig Address    
    address private immutable _ArtBlocksMintingContractAddress = 0x296FF13607C80b550dd136435983734c889Ccca4;    //ArtBlocks Ropsten Minting Contract
    address private immutable _ArtBlocksCoreContractAddress = 0xDbc3EaB9D16902d611a9D234ea9B2eaE3432B5BE;       //Artblocks Ropsten NFT Collection Contract
    address private _MintPassContractAddress = 0x63C17E65c5223C1E633F66E83c5b0D37a2a1a484;
    address private _GoldenTicketCity5 = 0xb7d614DfA9147712e9CA055b3E149Fd7f5Dd75Bc;
    address private _GoldenTicketCity6 = 0xD719e7cf93726B49A3a7EF545A3a94E1da5b41e3;
    address private _GoldenTicketCity7 = 0x5Eecd4E2651C0DfE0dCC4cdf0E3e62126ea36B11;
    address private _GoldenTicketCity8 = 0x8385f64a85D4DA0CfB0E79C8FA5276FfF91c86D1;
    address private _GoldenTicketCity9 = 0x3e87208529A4a7859e08897016dCbCa150962c81;
    address private _GoldenTicketCity10 = 0x84f478cbBdb0d293Ff42d905E0999A0CFF2b0471;
    uint256 private _ArtBlocksProjectID = 0;                                                    
    uint256 private _index = 0;
    
    // Pre-Approves 1000 BRT For Purchasing (denoted in WEI)
    constructor() 
    { 
        approveBRT(1000000000000000000000); 
    }

    // Sends Golden Ticket & Whitelists Address to receive CryptoCitizen
    function _redeemMintPass(uint256 passportTokenID) public nonReentrant whenNotPaused
    {
        require(IERC721(_MintPassContractAddress).ownerOf(passportTokenID) == msg.sender, "Sender Does Not Own Mint Pass With The Input Token ID");
        IERC721(_MintPassContractAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, passportTokenID);
        mintGalactican(msg.sender, mintArtBlocks());
        IERC721(_GoldenTicketCity5).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity6).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity7).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity8).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity9).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity10).safeTransferFrom(address(this), msg.sender, _index);
        _index += 1;
    }

    function approveBRT(uint256 amount) private onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    function mintArtBlocks() private returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); }

    function mintGalactican(address to, uint256 tokenID) private { IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); }

    // Withdraws ERC20 Tokens to Multisig
    function __withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
    }  

    // Withdraws Ether to Multisig
    function __withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }

    //Withdraws NFT to Multisig
    function __withdrawNFT(address contractAddress, uint256 tokenID) public onlyOwner { IERC721(contractAddress).safeTransferFrom(address(this), _BRTMULTISIG, tokenID); }

    //Pauses Functionality
    function __pause() public onlyOwner { _pause(); }

    //Unpauses Functionality
    function __unpause() public onlyOwner { _unpause(); }
}