//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./VoxmonSignature.sol";
import "hardhat/console.sol";

contract VoxmonNFT is ERC721URIStorage, AccessControl, VoxmonSignature {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _tokensMinted;
      
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint16 public maxTotal = 10000;

    constructor(address payable minter)
    ERC721("VoxmonNFT", "NFT") {
      _setupRole(MINTER_ROLE, minter);
    }
    
    mapping (uint256 => address) internal tokenIdToOwner;
    mapping (uint256 => string) internal tokenIdToAttrName;
    mapping (uint256 => string) private _tokenURIs;

    mapping (address => uint256) pendingWithdrawals;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }


    ///  Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    ///  The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    ///  The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
    ///  The metadata URI to associate with this token.
  
    function _isOwner(address sender, uint256 tokenId) 
    internal view
    returns (bool) {
        return ownerOf(tokenId) == sender;
    }
    

    function getTotalMinted() external view returns (uint256) {
        return _tokensMinted.current();
    }
    
    function getName(uint256 tokenId) external view returns (string memory) {
        return tokenIdToAttrName[tokenId];
    }
    
    // TODO: We likely will need to issue a voucher to record name changes.
    function changeName(string memory newName, uint256 tokenId, string memory newTokenURI) external  {
        require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: caller is not owner nor approved"
            );
        tokenIdToAttrName[tokenId] = newName;
        _setTokenURI(tokenId, newTokenURI);
    }
    
    function _isTokenAvailable() internal view returns (bool) {
        return _tokensMinted.current() < maxTotal;
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
    
    function withdraw() public {
        require(hasRole(MINTER_ROLE, msg.sender), "Only authorized minters can withdraw");
        
        // IMPORTANT: casting msg.sender to a payable address is only safe if ALL members of the minter role are payable addresses.
        address payable receiver = payable(msg.sender);
    
        uint amount = pendingWithdrawals[receiver];
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        receiver.transfer(amount);
    }
    
    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    ///  Redeems an NFTVoucher for an actual NFT, creating it in the process.
    ///  redeemer The address of the account which will receive the NFT upon success.
    ///  voucher An NFTVoucher that describes the NFT to be redeemed.
    ///  signature An EIP712 signature of the voucher, produced by the NFT creator.
    function redeem(address redeemer, NFTVoucher calldata voucher, Signature calldata sig) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        require(redeemer == voucher.forWallet, "Redeemer does not match voucher's 'forWallet' address");
        address signer = _verify(voucher, sig.v, sig.r, sig.s);
        console.log("got signer", signer);

        // // make sure that the signer is authorized to mint NFTs
        require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");
        console.log("signer has minter role", true);

        // // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");
        console.log("redeemer is fulfilling min price");

        // // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        console.log("minting");

        _setTokenURI(voucher.tokenId, voucher.uri);
        console.log("set token uri");
        
        // // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);
        console.log("transferring to redeemer");
        
        // // record payment to signer's withdrawal balance
        pendingWithdrawals[signer] += msg.value;
                
        return 1;
    }
    
    ///  Verifies the signature for a given NFTVoucher, returning the address of the signer.
    ///  Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    ///  voucher An NFTVoucher describing an unminted NFT.
    function _verify(NFTVoucher calldata voucher, uint8 v, bytes32 r, bytes32 s) public view returns (address) {
        //Call to VoxmonSignature.recover to extract signer's address from signature
        return recover(voucher, v, r, s);
    }

}