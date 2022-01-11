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
    address private immutable _ERC20_BRT_TokenAddress = 0x7Fee6e7FAf98af42eb83f3aA882d99D3D6aD4940;             //BRTNY Mainnet Contract Address   
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;                        //Bright Moments Multisig Mainnet Address    
    address private immutable _ArtBlocksMintingContractAddress = 0x24CCA47Fcc4fe09b51aBE8A8124C3da01765bE14;    //ArtBlocks Ropsten Minting Contract
    address private immutable _ArtBlocksCoreContractAddress = 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;       //Artblocks Mainnet NFT Collection Contract
    // address private immutable _MintPassContractAddress = address(0);
    // address private immutable _GoldenTicketCity5 = address(0); //ignore this lol
    // address private immutable _GoldenTicketCity6 = address(0);
    // address private immutable _GoldenTicketCity7 = address(0);
    // address private immutable _GoldenTicketCity8 = address(0);
    // address private immutable _GoldenTicketCity9 = address(0);
    // address private immutable _GoldenTicketCity10 = address(0);
    address private _MintPassContractAddress;
    address private _GoldenTicketCity5;
    address private _GoldenTicketCity6;
    address private _GoldenTicketCity7;
    address private _GoldenTicketCity8;
    address private _GoldenTicketCity9;
    address private _GoldenTicketCity10;
    uint256 private _ArtBlocksProjectID = 189;                                                        //CNY ArtBlocks Project ID
    uint256 private _index = 0;
    
    // Pre-Approves 1000 BRT For Purchasing (denoted in WEI)
    constructor() 
    { 
        // approveBRT(1000000000000000000000); 
    }

    // Sends Golden Ticket & Whitelists Address to receive CryptoCitizen
    function _redeemMintPass(uint256 passportTokenID) public nonReentrant whenNotPaused
    {
        require(IERC721(_MintPassContractAddress).ownerOf(passportTokenID) == msg.sender, "Sender Does Not Own Mint Pass With The Input Token ID");
        IERC721(_MintPassContractAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, passportTokenID);
        // mintGalactican(msg.sender, mintArtBlocks());
        IERC721(_GoldenTicketCity5).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity6).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity7).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity8).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity9).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity10).safeTransferFrom(address(this), msg.sender, _index);
        _index += 1;
    }

    function approveBRT(uint256 amount) public onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    function mintArtBlocks() private returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); }

    function mintGalactican(address to, uint256 tokenID) private { IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), to, tokenID); }

    // Withdraws ERC20 Tokens to Multisig
    function withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
    }  

    // Withdraws Ether to Multisig
    function withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }

    //Withdraws NFT to Multisig
    function withdrawNFT(address contractAddress, uint256 tokenID) public onlyOwner { IERC721(contractAddress).safeTransferFrom(address(this), _BRTMULTISIG, tokenID); }

    //Pauses Functionality
    function pause() public onlyOwner { _pause(); }

    //Unpauses Functionality
    function unpause() public onlyOwner { _unpause(); }

    function addContractAddresses(address[] calldata addresses) public onlyOwner
    {
        _GoldenTicketCity5 = addresses[0];
        _GoldenTicketCity6 = addresses[1];
        _GoldenTicketCity7 = addresses[2];
        _GoldenTicketCity8 = addresses[3];
        _GoldenTicketCity9 = addresses[4];
        _GoldenTicketCity10 = addresses[5];
        _MintPassContractAddress = addresses[6];
    }
}