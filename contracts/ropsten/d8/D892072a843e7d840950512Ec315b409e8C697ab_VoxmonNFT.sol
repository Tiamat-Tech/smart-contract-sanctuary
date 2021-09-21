//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract VoxmonNFT is EIP712, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _tokensMinted;
      
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint16 public maxTotal = 10000;

    constructor(address payable minter)
    ERC721("VoxmonNFT", "NFT")
    EIP712("LazyNFT-Voucher", "1") {
      _setupRole(MINTER_ROLE, minter);
    }
    
    mapping (uint256 => address) internal tokenIdToOwner;
    mapping (uint256 => string) internal tokenIdToAttrName;
    mapping (uint256 => string) private _tokenURIs;

    mapping (address => uint256) pendingWithdrawals;


    ///  Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    ///  The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    ///  The minimum price (in wei) that the NFT creator is willing to accept for the initial sale of this NFT.
    ///  The metadata URI to associate with this token.

    struct NFTVoucher {
        uint256 tokenId;
    
        uint256 minPrice;
    
        string uri;
        
        string name;
    }     
  
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
    function redeem(address redeemer, NFTVoucher calldata voucher, bytes memory signature) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher, signature);
        
        // make sure that the signer is authorized to mint NFTs
        require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");
        
        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.minPrice, "Insufficient funds to redeem");
        
        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.uri);
        tokenIdToAttrName[voucher.tokenId] = voucher.name;

        
        
        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);
        
        // record payment to signer's withdrawal balance
        pendingWithdrawals[signer] += msg.value;
        
        _tokensMinted.increment();
        
        return voucher.tokenId;
    }
    
    /// @notice Returns a hash of the given NFTVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An NFTVoucher to hash.
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri,string name)"),
            voucher.tokenId,
            voucher.minPrice,
            keccak256(bytes(voucher.uri)),
            keccak256(bytes(voucher.name))
        )));
    }
    
    
    ///  Verifies the signature for a given NFTVoucher, returning the address of the signer.
    ///  Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    ///  voucher An NFTVoucher describing an unminted NFT.
    ///  signature An EIP712 signature of the given voucher.
    function _verify(NFTVoucher calldata voucher, bytes memory signature) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return digest.toEthSignedMessageHash().recover(signature);
    }
}