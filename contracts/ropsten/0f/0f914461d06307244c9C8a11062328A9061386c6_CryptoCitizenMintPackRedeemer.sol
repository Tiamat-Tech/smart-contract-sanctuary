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
    address private immutable _MintPassHolder = 0x15f0B1b340B12A01ca521e762825681cd6dd87Aa;
    address private immutable _GoldenTicketCity5 = 0xa4F4374e14f7cF3cB1c4E6792F07b5a92902adC8;
    address private immutable _GoldenTicketCity6 = 0xfd472787B314493D39fe3D2A3C314db82F8f44A8;
    address private immutable _GoldenTicketCity7 = 0x35f56B3193feB9e2054A9D2612254A996cedEF86;
    address private immutable _GoldenTicketCity8 = 0x3F3e8271ecA4Db6932f0E1328cA8e358E87cD534;
    address private immutable _GoldenTicketCity9 = 0x8ff51CDf0b911FBa4E06B7Debdbd61e94d5df6bC;
    address private immutable _GoldenTicketCity10 = 0xc7584509e47928695e2fe778b783C9283E82df35;
    address private immutable _MintPassContractAddress = 0x63C17E65c5223C1E633F66E83c5b0D37a2a1a484;
    uint256 private immutable _ArtBlocksProjectID = 0;                                                          //Galactican Project ID                                                 
    uint256 private _index = 0;
    
    // Pre-Approves 1000 BRT For Purchasing (denoted in WEI)
    constructor() { approveBRT(1000000000000000000000); }

    // Redeems CryptoCitizen Mint Pass
    function _redeemMintPass(uint256 passportTokenID) public nonReentrant whenNotPaused
    {
        require(IERC721(_MintPassContractAddress).ownerOf(passportTokenID) == msg.sender, "Sender Does Not Own Mint Pass With The Input Token ID");

        IERC721(_MintPassContractAddress).safeTransferFrom(msg.sender, _BRTMULTISIG, passportTokenID);

        // Mints Galactican
        uint256 _ArtBlocksTokenID = mintGalactican();
        IERC721(_ArtBlocksCoreContractAddress).safeTransferFrom(address(this), msg.sender, _ArtBlocksTokenID);

        // Transfers Golden Token City 5
        IERC721(_GoldenTicketCity5).safeTransferFrom(_MintPassHolder, address(this), _index);
        IERC721(_GoldenTicketCity5).safeTransferFrom(address(this), msg.sender, _index);

        // Transfers Golden Token City 6
        IERC721(_GoldenTicketCity6).safeTransferFrom(_MintPassHolder, address(this), _index);
        IERC721(_GoldenTicketCity6).safeTransferFrom(address(this), msg.sender, _index);

        // Transfers Golden Token City 7
        IERC721(_GoldenTicketCity7).safeTransferFrom(_MintPassHolder, address(this), _index);
        IERC721(_GoldenTicketCity7).safeTransferFrom(address(this), msg.sender, _index);

        // Transfers Golden Token City 8
        IERC721(_GoldenTicketCity8).safeTransferFrom(_MintPassHolder, address(this), _index);
        IERC721(_GoldenTicketCity8).safeTransferFrom(address(this), msg.sender, _index);

        // Transfers Golden Token City 9
        IERC721(_GoldenTicketCity9).safeTransferFrom(_MintPassHolder, address(this), _index);
        IERC721(_GoldenTicketCity9).safeTransferFrom(address(this), msg.sender, _index);

        // Transfers Golden Token City 10
        IERC721(_GoldenTicketCity10).safeTransferFrom(_MintPassHolder, address(this), _index);
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
}