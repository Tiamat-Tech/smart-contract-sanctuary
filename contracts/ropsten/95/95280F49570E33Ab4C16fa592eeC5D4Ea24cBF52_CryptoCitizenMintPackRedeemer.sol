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
    address private immutable _ArtBlocksCoreContractAddress = 0x24CCA47Fcc4fe09b51aBE8A8124C3da01765bE14;       //Artblocks Ropsten NFT Collection Contract
    uint256 private immutable _ArtBlocksProjectID = 0;                                                          //Galactican Project ID                                                 
    address public _MintPassContractAddress;
    address public _GoldenTicketCity5;
    address public _GoldenTicketCity6;
    address public _GoldenTicketCity7;
    address public _GoldenTicketCity8;
    address public _GoldenTicketCity9;
    address public _GoldenTicketCity10;
    uint256 private _index = 0;
    
    // Pre-Approves 1000 BRT For Purchasing (denoted in WEI)
    constructor() { approveBRT(1000000000000000000000); }

    // Redeems CryptoCitizen Mint Pass
    function _redeemMintPass(uint256 passportTokenID) public nonReentrant whenNotPaused
    {
        require(IERC721(_MintPassContractAddress).ownerOf(passportTokenID) == msg.sender, "Sender Does Not Own Mint Pass With The Input Token ID");
        IERC721(_MintPassContractAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, passportTokenID);
        uint256 _ArtBlocksTokenID = mintGalactican();
        IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), msg.sender, _ArtBlocksTokenID);
        IERC721(_GoldenTicketCity5).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity6).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity7).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity8).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity9).safeTransferFrom(address(this), msg.sender, _index);
        IERC721(_GoldenTicketCity10).safeTransferFrom(address(this), msg.sender, _index);
        _index += 1;
    }

    // Approves BRT for Galactican Purchasing
    function approveBRT(uint256 amount) private onlyOwner { IERC20(_ERC20_BRT_TokenAddress).approve(_ArtBlocksMintingContractAddress, amount); }

    // Mints Galactican From ArtBlocks Minting Contract
    function mintGalactican() private returns (uint tokenID) { return IArtBlocks(_ArtBlocksMintingContractAddress).purchase(_ArtBlocksProjectID); }

    // Withdraws ERC20 Tokens to Multisig
    function __withdrawERC20(address tokenAddress) public onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this)));
    }  

    // Withdraws Ether to Multisig
    function __withdrawEther() public onlyOwner { payable(_BRTMULTISIG).transfer(address(this).balance); }

    // Withdraws NFT to Multisig
    function __withdrawNFT(address contractAddress, uint256 tokenID) public onlyOwner { IERC721(contractAddress).safeTransferFrom(address(this), _BRTMULTISIG, tokenID); }

    // Pauses Functionality
    function __pause() public onlyOwner { _pause(); }

    // Unpauses Functionality
    function __unpause() public onlyOwner { _unpause(); }

    // Adds contract addresses (for testnet use only)
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

    function transferNFTs(address to, uint256 start, uint256 end) public onlyOwner
    {
        for(uint256 i = start; i < end; i++)
        {
            IERC721(_GoldenTicketCity5).safeTransferFrom(address(this), to, i);
            IERC721(_GoldenTicketCity6).safeTransferFrom(address(this), to, i);
            IERC721(_GoldenTicketCity7).safeTransferFrom(address(this), to, i);
            IERC721(_GoldenTicketCity8).safeTransferFrom(address(this), to, i);
            IERC721(_GoldenTicketCity9).safeTransferFrom(address(this), to, i);
            IERC721(_GoldenTicketCity10).safeTransferFrom(address(this), to, i);
        }
    }
}